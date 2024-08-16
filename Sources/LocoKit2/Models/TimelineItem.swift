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

    public var isValid: Bool { return true }

    public var isInvalid: Bool { !isValid }

    public var isWorthKeeping: Bool { return true }

    public var isDataGap: Bool { return false }

    public var isNolo: Bool { return false }

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

    public func previousItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.previousItem(for: self)
    }

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
        if isWorthKeeping { return 2 }
        if isValid { return 1 }
        return 0
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

    public func isWithinMergeableDistance(of otherItem: TimelineItem) -> Bool? {
        if self.isNolo || otherItem.isNolo { return true }
//        if let gap = distance(from: otherItem), gap <= maximumMergeableDistance(from: otherItem) { return true }

        // if the items overlap in time, any physical distance is acceptable
//        guard let timeGap = self.timeInterval(from: otherItem), timeGap < 0 else { return true }

        return false
    }

    public func distance(from otherItem: TimelineItem) -> CLLocationDistance? {
        if self.isVisit, let selfVisit = self.visit {
            return selfVisit.distance(from: otherItem)
        }
        if self.isTrip, let selfTrip = self.trip {
            return selfTrip.distance(from: otherItem)
        }
        fatalError()
    }

    public func edgeSample(withOtherItemId otherItemId: String) -> LocomotionSample? {
        if otherItemId == base.previousItemId {
            return samples?.first
        }
        if otherItemId == base.nextItemId {
            return samples?.last
        }
        return nil
    }

    internal func sanitiseEdges(in list: TimelineLinkedList, excluding: Set<LocomotionSample> = []) async -> Set<LocomotionSample> {
        var movedSamples: Set<LocomotionSample> = []

        // Sanitise with previous item
        if let previousItem = await previousItem(in: list) {
            let movedWithPrevious = await sanitiseEdgeWith(previousItem, in: list, excluding: excluding)
            movedSamples.formUnion(movedWithPrevious)
        }

        // Sanitise with next item
        if let nextItem = await nextItem(in: list) {
            let movedWithNext = await sanitiseEdgeWith(nextItem, in: list, excluding: excluding)
            movedSamples.formUnion(movedWithNext)
        }

        return movedSamples
    }

    internal func sanitiseEdgeWith(_ otherItem: TimelineItem, in list: TimelineLinkedList, excluding: Set<LocomotionSample>) async -> Set<LocomotionSample> {
        // TODO: Implement the actual edge sanitising logic
        // This should involve:
        // 1. Determining which samples should be moved
        // 2. Moving samples between this item and otherItem
        // 3. Updating both items' samples collections
        // 4. Returning the set of moved samples

        return []
    }

    // MARK: - Private

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
