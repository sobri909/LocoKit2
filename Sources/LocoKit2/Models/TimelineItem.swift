//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import CoreLocation
import Combine
@preconcurrency import GRDB

public struct TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable, Sendable {

    public var base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public var trip: TimelineItemTrip?

    public internal(set) var samples: [LocomotionSample]? {
        didSet {
            if let samples {
                self.segments = Self.collateSegments(from: samples, disabled: disabled)
            } else {
                self.segments = nil
            }
        }
    }

    public internal(set) var segments: [ItemSegment]?

    // MARK: -

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var isTrip: Bool { !base.isVisit }
    public var dateRange: DateInterval? { base.dateRange }
    public var source: String { base.source }
    public var disabled: Bool { base.disabled }
    public var deleted: Bool { base.deleted }
    public var samplesChanged: Bool { base.samplesChanged }
    
    public var debugShortId: String { String(id.split(separator: "-")[0]) }

    public var coordinates: [CLLocationCoordinate2D]? {
        return samples?.compactMap { $0.coordinate }.filter { $0.isUsable }
    }

    // MARK: -

    public var isValid: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            guard let dateRange else { return false }

            if isVisit {
                // Visit specific validity logic
                if samples.isEmpty { return false }
                if try isNolo { return false }
                if dateRange.duration < TimelineItemVisit.minimumValidDuration { return false }
                return true
                
            } else {
                // Trip specific validity logic
                if samples.count < TimelineItemTrip.minimumValidSamples { return false }
                if dateRange.duration < TimelineItemTrip.minimumValidDuration { return false }
                if let distance = trip?.distance, distance < TimelineItemTrip.minimumValidDistance { return false }
                return true
            }
        }
    }

    public var isInvalid: Bool {
        get throws { try !isValid }
    }

    public var isWorthKeeping: Bool {
        get throws {
            if try !isValid { return false }

            guard let dateRange else { return false }

            if isVisit {
                // Visit-specific worth keeping logic
                if dateRange.duration < TimelineItemVisit.minimumKeeperDuration { return false }
                return true
            } else {
                // Trip-specific worth keeping logic
                if dateRange.duration < TimelineItemTrip.minimumKeeperDuration { return false }
                if let distance = trip?.distance, distance < TimelineItemTrip.minimumKeeperDistance { return false }
                return true
            }
        }
    }

    public var isDataGap: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            if isVisit { return false }
            if samples.isEmpty { return false }

            return samples.allSatisfy { $0.recordingState == .off }
        }
    }

    public var isNolo: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            if try isDataGap { return false }
            return samples.allSatisfy { $0.location == nil }
        }
    }

    public var typeString: String {
        get throws {
            if try isDataGap { return "datagap" }
            if try isNolo    { return "nolo" }
            if isVisit       { return "visit" }
            return "trip"
        }
    }

    public var title: String {
        get throws {
            if try isDataGap {
                return "Data Gap"
            }

            if let trip {
                if let activityType = trip.activityType {
                    return activityType.displayName.capitalized
                }
                return "Transport"
            }

            // must be a visit
            if try isWorthKeeping {
                return "Unknown Place"
            }
            return "Brief Stop"
        }
    }

    public var description: String {
        get throws {
            String(format: "%@ %@", try keepnessString, try typeString)
        }
    }

    // MARK: - Relationships

    @TimelineActor
    public func previousItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.previousItem(for: self)
    }

    @TimelineActor
    public func nextItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.nextItem(for: self)
    }

    // TODO: the db does this now with triggers. bad form to do it here too?
    public mutating func breakEdges() {
        base.previousItemId = nil
        base.nextItemId = nil
    }

    // MARK: - Item creation

    public static func createItem(from samples: [LocomotionSample], isVisit: Bool) async throws -> TimelineItem {
        let base = TimelineItemBase(isVisit: isVisit)
        let visit: TimelineItemVisit?
        let trip: TimelineItemTrip?

        if isVisit {
            visit = TimelineItemVisit(itemId: base.id, samples: samples)
            trip = nil
        } else {
            trip = TimelineItemTrip(itemId: base.id, samples: samples)
            visit = nil
        }

        let newItem = try await Database.pool.write { [base, visit, trip] in
            try base.save($0)
            try visit?.save($0)
            try trip?.save($0)
            for var sample in samples {
                try sample.updateChanges($0) {
                    $0.timelineItemId = base.id
                }
            }

            return try TimelineItem
                .itemRequest(includeSamples: false)
                .filter(Column("id") == base.id)
                .fetchOne($0)
        }

        guard let newItem else {
            throw TimelineError.itemNotFound
        }
        
        return newItem
    }

    // MARK: - Item fetching

    public static func fetchItem(itemId: String, includeSamples: Bool) async throws -> TimelineItem? {
        return try await Database.pool.read {
            return try itemRequest(includeSamples: includeSamples)
                .filter(Column("id") == itemId)
                .fetchOne($0)
        }
    }

    public static func itemRequest(includeSamples: Bool) -> QueryInterfaceRequest<TimelineItem> {
        var request = TimelineItemBase
            .including(optional: TimelineItemBase.visit)
            .including(optional: TimelineItemBase.trip)

        if includeSamples {
            request = request.including(all: TimelineItemBase.samples)
        }

        return request
            .asRequest(of: TimelineItem.self)
    }

    // MARK: - Sample fetching

    public mutating func fetchSamples() async {
        guard samplesChanged || samples == nil else {
            print("[\(debugShortId)] fetchSamples() skipping; no reason to fetch")
            return
        }

        do {
            let fetchedSamples = try await Database.pool.read { [base] in
                try base.samples
                    .order(Column("date").asc)
                    .fetchAll($0)
            }

            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    private static func collateSegments(from samples: [LocomotionSample], disabled: Bool) -> [ItemSegment] {
        var segments: [ItemSegment] = []
        var currentSamples: [LocomotionSample] = []

        for sample in samples where sample.disabled == disabled {
            if currentSamples.isEmpty || sample.activityType == currentSamples.first?.activityType {
                currentSamples.append(sample)
            } else {
                if let segment = ItemSegment(samples: currentSamples) {
                    segments.append(segment)
                }
                currentSamples = [sample]
            }
        }

        // add the last segment if there are any remaining samples
        if !currentSamples.isEmpty, let segment = ItemSegment(samples: currentSamples) {
            segments.append(segment)
        }

        return segments
    }

    public mutating func classifySamples() async {
        guard let samples else { return }
        guard let results = await ActivityClassifier.highlander.results(for: samples) else { return }

        do {
            self.samples = try await Database.pool.write { db in
                var updatedSamples: [LocomotionSample] = []
                for var mutableSample in samples {
                    if let result = results.perSampleResults[mutableSample.id] {
                        if mutableSample.classifiedActivityType != result.bestMatch.activityType {
                            try mutableSample.updateChanges(db) {
                                $0.classifiedActivityType = result.bestMatch.activityType
                            }
                        }
                    }
                    updatedSamples.append(mutableSample)
                }
                return updatedSamples
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Timeline processing

    @TimelineActor
    public func scoreForConsuming(_ item: TimelineItem) -> ConsumptionScore {
        return MergeScores.consumptionScoreFor(self, toConsume: item)
    }

    public var keepnessScore: Int {
        get throws {
            if try isWorthKeeping { return 2 }
            if try isValid { return 1 }
            return 0
        }
    }

    public var keepnessString: String {
        get throws {
            if try isWorthKeeping { return "keeper" }
            if try isValid { return "valid" }
            return "invalid"
        }
    }

    internal func willConsume(_ otherItem: TimelineItem) {
        if otherItem.isVisit {
            // if self.swarmCheckinId == nil, otherItem.swarmCheckinId != nil {
            //     self.swarmCheckinId = otherItem.swarmCheckinId
            // }
            // if self.customTitle == nil, otherItem.customTitle != nil {
            //     self.customTitle = otherItem.customTitle
            // }
        }
    }

    internal func isWithinMergeableDistance(of otherItem: TimelineItem) throws -> Bool {
        if try self.isNolo { return true }
        if try otherItem.isNolo { return true }

        if let gap = try distance(from: otherItem), gap <= maximumMergeableDistance(from: otherItem) { return true }

        // if the items overlap in time, any physical distance is acceptable
        if timeInterval(from: otherItem) < 0 { return true }

        return false
    }

    private func maximumMergeableDistance(from otherItem: TimelineItem) -> CLLocationDistance {
        if self.isVisit {
            return maximumMergeableDistanceForVisit(from: otherItem)
        } else {
            return maximumMergeableDistanceForTrip(from: otherItem)
        }
    }

    // VISIT <-> OTHER
    private func maximumMergeableDistanceForVisit(from otherItem: TimelineItem) -> CLLocationDistance {

        // VISIT <-> VISIT
        if otherItem.isVisit {
            return .greatestFiniteMagnitude
        }

        // VISIT <-> TRIP

        // visit-trip gaps less than this should be forgiven
        let minimum: CLLocationDistance = 150

        let timeSeparation = abs(self.timeInterval(from: otherItem))
        let rawMax = CLLocationDistance(otherItem.trip?.speed ?? 0 * timeSeparation * 4)

        return max(rawMax, minimum)
    }

    // TRIP <-> OTHER
    private func maximumMergeableDistanceForTrip(from otherItem: TimelineItem) -> CLLocationDistance {

        // TRIP <-> VISIT
        if otherItem.isVisit {
            return otherItem.maximumMergeableDistance(from: self)
        }

        // TRIP <-> TRIP

        let timeSeparation = abs(self.timeInterval(from: otherItem))

        let selfSpeed = self.trip?.speed ?? 0
        let otherSpeed = otherItem.trip?.speed ?? 0
        let maxSpeed = max(selfSpeed, otherSpeed)

        return CLLocationDistance(maxSpeed * timeSeparation * 50)
    }

    // MARK: -

    public func distance(from otherItem: TimelineItem) throws -> CLLocationDistance? {
        if self.isVisit {
            return try visit?.distance(from: otherItem)

        } else {
            if otherItem.isVisit {
                return try otherItem.visit?.distance(from: self)

            } else {
                return try distanceFromTripToTrip(otherItem)
            }
        }
    }

    private func distanceFromTripToTrip(_ otherItem: TimelineItem) throws -> CLLocationDistance? {
        guard self.isTrip, otherItem.isTrip else { fatalError() }

        guard let samples, let otherSamples = otherItem.samples else {
            throw TimelineError.samplesNotLoaded
        }

        guard let selfStart = dateRange?.start,
              let otherStart = otherItem.dateRange?.start else {
            return nil
        }

        if selfStart < otherStart {
            guard let selfEdge = samples.last?.location,
                  let otherEdge = otherSamples.first?.location else {
                return nil
            }
            return selfEdge.distance(from: otherEdge)

        } else {
            guard let selfEdge = samples.first?.location,
                  let otherEdge = otherSamples.last?.location else {
                return nil
            }
            return selfEdge.distance(from: otherEdge)
        }
    }

    // a negative value indicates overlapping items, thus the duration of their overlap
    public func timeInterval(from otherItem: TimelineItem) -> TimeInterval {
        guard let myRange = self.dateRange,
              let theirRange = otherItem.dateRange else {
            return .greatestFiniteMagnitude
        }

        // case 1: items overlap
        if let intersection = myRange.intersection(with: theirRange) {
            return -intersection.duration
        }

        // case 2: this item is entirely before the other item
        if myRange.end <= theirRange.start {
            return theirRange.start.timeIntervalSince(myRange.end)
        }

        // case 3: this item is entirely after the other item
        return myRange.start.timeIntervalSince(theirRange.end)
    }

    // TODO: need to look for Place, to use Place radius instead, if available
    // (old ArcPath has an overload for this)
    public func samplesInside(_ visit: TimelineItemVisit) throws -> [LocomotionSample] {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        return samples.filter { sample in
            if let location = sample.location {
                return visit.contains(location)
            }
            return false
        }
    }

    public func percentInside(_ visit: TimelineItemVisit) throws -> Double {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if samples.isEmpty { return 0 }

        let samplesInsideVisit = try self.samplesInside(visit)

        return Double(samplesInsideVisit.count) / Double(samples.count)
    }

    // MARK: -

    public func edgeSample(withOtherItemId otherItemId: String) throws -> LocomotionSample? {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if otherItemId == base.previousItemId {
            return samples.first
        }
        if otherItemId == base.nextItemId {
            return samples.last
        }

        return nil
    }

    public func secondToEdgeSample(withOtherItemId otherItemId: String) throws -> LocomotionSample? {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if otherItemId == base.previousItemId {
            return samples.second
        }
        if otherItemId == base.nextItemId {
            return samples.secondToLast
        }

        return nil
    }

    // MARK: - Updating Visit and Trip

    private mutating func updateFrom(samples updatedSamples: [LocomotionSample]) async {
        guard samplesChanged else {
            print("[\(debugShortId)] updateFrom(samples:) skipping; no reason to update")
            return
        }

        let oldBase = base
        let oldTrip = trip
        let oldVisit = visit

        await visit?.update(from: updatedSamples)
        await trip?.update(from: updatedSamples)

        base.samplesChanged = false

        do {
            try await Database.pool.write { [base, visit, trip] db in
                try base.updateChanges(db, from: oldBase)
                if let oldVisit {
                    try visit?.updateChanges(db, from: oldVisit)
                }
                if let oldTrip {
                    try trip?.updateChanges(db, from: oldTrip)
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, samples
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        base = try container.decode(TimelineItemBase.self, forKey: .base)
        visit = try container.decodeIfPresent(TimelineItemVisit.self, forKey: .visit)
        trip = try container.decodeIfPresent(TimelineItemTrip.self, forKey: .trip)
        samples = try container.decodeIfPresent([LocomotionSample].self, forKey: .samples)
        if let samples {
            segments = Self.collateSegments(from: samples, disabled: base.disabled)
        }
    }

}
