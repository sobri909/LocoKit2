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

public enum TimelineItemError: Error {
    case samplesNotLoaded

    public var description: String {
        switch self {
        case .samplesNotLoaded:
            return "TimelineItemError.samplesNotLoaded"
        }
    }
}

public struct TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable, Sendable {

    public var base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public var trip: TimelineItemTrip?
    public internal(set) var samples: [LocomotionSample]?

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var isTrip: Bool { !base.isVisit }
    public var dateRange: DateInterval { base.dateRange }
    public var source: String { base.source }
    public var disabled: Bool { base.disabled }
    public var deleted: Bool { base.deleted }
    public var samplesChanged: Bool { base.samplesChanged }
    
    public var debugShortId: String { String(id.split(separator: "-")[0]) }

    // MARK: -

    public var coordinates: [CLLocationCoordinate2D]? {
        return samples?.compactMap { $0.coordinate }.filter { $0.isUsable }
    }

    public var isValid: Bool {
        get throws {
            guard let samples else {
                throw TimelineItemError.samplesNotLoaded
            }

            if isVisit {
                // Visit-specific validity logic
                if samples.isEmpty { return false }
                if try isNolo { return false }
                if dateRange.duration < TimelineItemVisit.minimumValidDuration { return false }
                return true
            } else {
                // Path-specific validity logic
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
                throw TimelineItemError.samplesNotLoaded
            }

            if isVisit { return false }
            if samples.isEmpty { return false }

            return samples.allSatisfy { $0.recordingState == .off }
        }
    }

    public var isNolo: Bool {
        get throws {
            guard let samples else {
                throw TimelineItemError.samplesNotLoaded
            }

            if try isDataGap { return false }
            return !samples.contains { $0.location != nil }
        }
    }

    // MARK: - Relationships

    public mutating func fetchSamples() async {
        guard samplesChanged || samples == nil else {
            print("[\(debugShortId)] fetchSamples() skipping; no reason to fetch")
            return
        }

        do {
            let samplesRequest = base.samples.order(Column("date").asc)
            let fetchedSamples = try await Database.pool.read {
                try samplesRequest.fetchAll($0)
            }

            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    @TimelineActor
    public func previousItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.previousItem(for: self)
    }

    @TimelineActor
    public func nextItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.nextItem(for: self)
    }

    public mutating func breakEdges() {
        base.previousItemId = nil
        base.nextItemId = nil
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
        var speeds: [CLLocationSpeed] = []
        if let selfSpeed = self.trip?.speed, selfSpeed > 0 {
            speeds.append(selfSpeed)
        }
        if let otherSpeed = otherItem.trip?.speed, otherSpeed > 0 {
            speeds.append(otherSpeed)
        }
        return CLLocationDistance(speeds.mean() * timeSeparation * 4)
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
            throw TimelineItemError.samplesNotLoaded
        }

        let selfStart = dateRange.start
        let otherStart = otherItem.dateRange.start

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
        let myRange = self.dateRange
        let theirRange = otherItem.dateRange

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

    public func edgeSample(withOtherItemId otherItemId: String) throws -> LocomotionSample? {
        guard let samples else {
            throw TimelineItemError.samplesNotLoaded
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
            throw TimelineItemError.samplesNotLoaded
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

        let visitChanged = visit?.update(from: updatedSamples) ?? false
        let tripChanged = trip?.update(from: updatedSamples) ?? false
        base.samplesChanged = false

        let baseCopy = base
        let visitCopy = visit
        let tripCopy = trip
        do {
            try await Database.pool.write {
                if visitChanged { try visitCopy?.save($0) }
                if tripChanged { try tripCopy?.save($0) }
                try baseCopy.save($0)
            }
            
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, samples
    }

    // MARK: - Hashable

    public static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
