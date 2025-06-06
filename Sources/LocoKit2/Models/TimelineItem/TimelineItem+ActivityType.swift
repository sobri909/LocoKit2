//
//  TimelineItem+ActivityType.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 23/12/2024.
//

import Foundation

extension TimelineItem {

    public mutating func classifySamples() async {
        guard let samples else { return }
        guard let results = await ActivityClassifier.results(for: samples) else { return }
        let trip = self.trip

        do {
            self.samples = try await Database.pool.write { db in
                var updatedSamples: [LocomotionSample] = []
                for var mutableSample in samples {
                    defer { updatedSamples.append(mutableSample) }

                    guard let result = results.perSampleResults[mutableSample.id] else { continue }
                    guard let bestMatch = result.bestMatch else { continue }

                    if mutableSample.classifiedActivityType != bestMatch.activityType {
                        try mutableSample.updateChanges(db) {
                            $0.classifiedActivityType = bestMatch.activityType
                        }
                    }
                }

                // update trip uncertainty if this is a trip and we have combined results
                if let combinedResults = results.combinedResults {
                    if var mutableTrip = trip {
                        try mutableTrip.updateChanges(db) {
                            $0.updateUncertainty(from: combinedResults)
                        }
                    }
                }

                return updatedSamples
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public mutating func changeActivityType(to confirmedType: ActivityType) async throws {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        var samplesToConfirm: [LocomotionSample] = []

        for sample in samples {
            // let confident stationary samples survive, when changing to a non-stationary type
            if confirmedType != .stationary, sample.hasUsableCoordinate, sample.activityType == .stationary {
                if let typeScore = await sample.classifierResults?[.stationary]?.score, typeScore > 0.5 {
                    continue
                }
            }

            // let manual bogus samples survive
            if sample.confirmedActivityType == .bogus { continue }

            samplesToConfirm.append(sample)
        }

        if !samplesToConfirm.isEmpty {
            do {
                let changedSamples = try await Database.pool.write { [samplesToConfirm, trip] db in
                    // update the samples
                    var changed: [LocomotionSample] = []
                    for var sample in samplesToConfirm where sample.confirmedActivityType != confirmedType {
                        try sample.updateChanges(db) {
                            $0.confirmedActivityType = confirmedType
                        }
                        changed.append(sample)
                    }

                    // update the Trip's activity type and uncertainty state
                    if var mutableTrip = trip {
                        try mutableTrip.updateChanges(db) {
                            $0.confirmedActivityType = confirmedType
                            $0.uncertainActivityType = false
                        }
                    }

                    return changed
                }

                // queue updates for the ML models
                await ActivityTypesManager.queueUpdatesForModelsContaining(changedSamples)

            } catch {
                logger.error(error, subsystem: .database)
                return
            }

            // need to refresh samples to ensure extraction uses updated segments
            await fetchSamples(forceFetch: true)
        }

        // if we're forcing it to stationary, extract all the stationary segments
        if confirmedType == .stationary, let segments {
            var itemsToProcess: [TimelineItem] = [self]
            for segment in segments where segment.activityType == .stationary {
                if let newItem = try await TimelineProcessor.extractItem(for: segment, isVisit: true) {
                    itemsToProcess.append(newItem)
                }
            }

            // cleanup after all that damage
            await TimelineProcessor.process(itemsToProcess)

        } else {
            // need to reprocess from self after the changes
            await TimelineProcessor.processFrom(itemId: self.id)
        }
    }

    public func cleanupSamples() async {
        if isVisit {
            await cleanupVisitSamples()
        } else {
            await cleanupTripSamples()
        }
        await TimelineProcessor.processFrom(itemId: self.id)
    }

    private func cleanupTripSamples() async {
        guard isTrip, let tripActivityType = trip?.activityType else { return }

        do {
            let samplesForCleanup = try await tripSamplesForCleanup

            let updatedSamples = try await Database.pool.write { db in
                var updated: [LocomotionSample] = []
                for var sample in samplesForCleanup {
                    try sample.updateChanges(db) {
                        $0.confirmedActivityType = tripActivityType
                    }
                    updated.append(sample)
                }
                return updated
            }

            if !updatedSamples.isEmpty {
                await ActivityTypesManager.queueUpdatesForModelsContaining(updatedSamples)
            }

        } catch {
            logger.error(error, subsystem: .activitytypes)
        }
    }

    private func cleanupVisitSamples() async {
        guard isVisit, let visit else { return }

        do {
            let samplesForCleanup = try visitSamplesForCleanup

            let updatedSamples = try await Database.pool.write { db in
                var updated: [LocomotionSample] = []
                for var sample in samplesForCleanup {
                    try sample.updateChanges(db) { sample in
                        if let location = sample.location {
                            let isInside = if let place = self.place {
                                place.contains(location, sd: 3)
                            } else {
                                visit.contains(location, sd: 3)
                            }

                            if isInside { // inside radius = stationary
                                sample.confirmedActivityType = .stationary
                            } else { // outside radius = bogus
                                sample.confirmedActivityType = .bogus
                            }
                        } else { // treat nolos as inside the radius
                            sample.confirmedActivityType = .stationary
                        }
                    }
                    updated.append(sample)
                }
                return updated
            }

            if !updatedSamples.isEmpty {
                await ActivityTypesManager.queueUpdatesForModelsContaining(updatedSamples)
            }

        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

    public var haveSamplesForCleanup: Bool {
        get async {
            do {
                if isVisit {
                    return try !visitSamplesForCleanup.isEmpty
                } else {
                    return try await !tripSamplesForCleanup.isEmpty
                }
            } catch {
                logger.error(error, subsystem: .timeline)
                return false
            }
        }
    }

    private var visitSamplesForCleanup: [LocomotionSample] {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            return samples.filter {
                if $0.confirmedActivityType != nil { return false } // don't mess with already confirmed
                if $0.activityType == .stationary { return false } // don't mess with already stationary
                return true
            }
        }
    }

    private var tripSamplesForCleanup: [LocomotionSample] {
        get async throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            guard isTrip, let tripActivityType = trip?.activityType else { return [] }

            var filteredSamples: [LocomotionSample] = []
            for sample in samples {
                if sample.confirmedActivityType != nil { continue } // don't mess with already confirmed
                if sample.activityType == tripActivityType { continue } // don't mess with already matching

                // let confident stationary samples survive
                if sample.hasUsableCoordinate, sample.activityType == .stationary {
                    if let typeScore = await sample.classifierResults?[.stationary]?.score, typeScore > 0.5 {
                        continue
                    }
                }

                filteredSamples.append(sample)
            }

            return filteredSamples
        }
    }
    
}
