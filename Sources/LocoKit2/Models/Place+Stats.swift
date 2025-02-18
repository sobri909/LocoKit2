//
//  Place+Stats.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 28/12/2024.
//

import Foundation
import GRDB

extension Place {

    @PlacesActor
    public mutating func updateVisitStats() async {
        do {
            let currentItemId = await TimelineRecorder.highlander.currentItemId

            let visits = try await Database.pool.read { [id] db in
                try TimelineItem
                    .itemRequest(includeSamples: true, includePlaces: true)
                    .filter(sql: "visit.placeId = ?", arguments: [id])
                    .filter(Column("deleted") == false)
                    .fetchAll(db)
            }

            if visits.isEmpty {
                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = 0
                        $0.visitDays = 0
                        $0.isStale = false
                        $0.arrivalTimes = nil
                        $0.leavingTimes = nil
                        $0.visitDurations = nil
                    }
                }
                return
            }

            // count unique visit days using place's timezone
            var calendar = Calendar.current
            calendar.timeZone = localTimeZone ?? .current

            let uniqueDays = Set<Date>(visits.compactMap {
                return $0.dateRange?.start.startOfDay(in: calendar)
            })

            let confirmedVisits = visits.filter { $0.visit?.confirmedPlace == true }
            let samples = confirmedVisits.flatMap { $0.samples ?? [] }

            // Only update if we have valid data to update with
            if let center = samples.weightedCenter() {
                let radius = samples.radius(from: center.location)

                let boundedMean = radius.mean.clamped(min: Place.minimumPlaceRadius, max: Place.maximumPlaceRadius)
                let boundedSD = radius.sd.clamped(min: 0, max: Place.maximumPlaceRadius)

                // use all visits for counts, samples, and arrival times
                let visitStarts = confirmedVisits.compactMap { $0.dateRange?.start }

                // filter out currentItem for leaving times and durations
                let statsVisits = confirmedVisits.filter { $0.id != currentItemId }
                let visitEnds = statsVisits.compactMap { $0.dateRange?.end }
                let visitDurations = statsVisits.compactMap { $0.dateRange?.duration }

                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = visits.count
                        $0.visitDays = uniqueDays.count
                        $0.latitude = center.latitude
                        $0.longitude = center.longitude
                        $0.radiusMean = boundedMean
                        $0.radiusSD = boundedSD
                        $0.isStale = false
                        $0.arrivalTimes = Histogram.forTimeOfDay(dates: visitStarts, timeZone: localTimeZone ?? .current)
                        $0.leavingTimes = Histogram.forTimeOfDay(dates: visitEnds, timeZone: localTimeZone ?? .current)
                        $0.visitDurations = Histogram.forDurations(intervals: visitDurations)
                    }
                    
                    Task { await mutableSelf.updateRTree() }
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public func leavingProbabilityFor(duration: TimeInterval, date: Date = .now) -> Double? {
        guard let leavingTimes = leavingTimes,
              let visitDurations = visitDurations else {
            return nil
        }

        // Get time of day in place's timezone
        var calendar = Calendar.current
        calendar.timeZone = localTimeZone ?? .current
        let timeOfDay = date.sinceStartOfDay(in: calendar)

        // both need to have non-nil probabilities for AND probability to make sense
        guard let timeBasedProbability = leavingTimes.probability(for: timeOfDay) else { return nil }
        guard let durationBasedProbability = visitDurations.probability(for: duration) else { return nil }

        // Using AND probability for most conservative estimate
        return timeBasedProbability * durationBasedProbability
    }

}
