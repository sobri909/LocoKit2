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

    public func isWithinMergeableDistance(of otherItem: TimelineItem) -> Bool {
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

    public func edgeSample(withOtherItemId otherItemId: String) -> LocomotionSample? {
        if otherItemId == base.previousItemId {
            return samples?.first
        }
        if otherItemId == base.nextItemId {
            return samples?.last
        }
        return nil
    }

    public func secondToEdgeSample(withOtherItemId otherItemId: String) -> LocomotionSample? {
        if otherItemId == base.previousItemId {
            return samples?.second
        }
        if otherItemId == base.nextItemId {
            return samples?.secondToLast
        }
        return nil
    }

    @TimelineActor
    internal func sanitiseEdges(in list: TimelineLinkedList, excluding: Set<LocomotionSample> = []) async -> Set<LocomotionSample> {
        var allMoved: Set<LocomotionSample> = []
        let maximumEdgeSteals = 30

        while allMoved.count < maximumEdgeSteals {
            var movedThisLoop: Set<LocomotionSample> = []

            if let previousItem = await previousItem(in: list), previousItem.source == self.source, previousItem.isTrip {
                if let moved = await cleanseEdge(with: previousItem, in: list, excluding: excluding.union(allMoved)) {
                    movedThisLoop.insert(moved)
                }
            }
            if let nextItem = await nextItem(in: list), nextItem.source == self.source, nextItem.isTrip {
                if let moved = await cleanseEdge(with: nextItem, in: list, excluding: excluding.union(allMoved)) {
                    movedThisLoop.insert(moved)
                }
            }

            // no changes, so we're done
            if movedThisLoop.isEmpty { break }

            // break from an infinite loop
            guard movedThisLoop.intersection(allMoved).isEmpty else { break }

            // keep track of changes
            allMoved.formUnion(movedThisLoop)
        }

        return allMoved
    }

    @TimelineActor
    private func cleanseEdge(with otherItem: TimelineItem, in list: TimelineLinkedList, excluding: Set<LocomotionSample>) async -> LocomotionSample? {
        // we only cleanse edges with Trips
        guard otherItem.isTrip else { return nil }

        guard !self.deleted && !otherItem.deleted else { return nil }
        guard self.source == otherItem.source else { return nil } // no edge stealing between different data sources
        guard isWithinMergeableDistance(of: otherItem) else { return nil }
        guard timeInterval(from: otherItem) < .minutes(10) else { return nil } // 10 mins seems like a lot?

        if self.isTrip {
            return await cleanseTripEdge(with: otherItem, in: list, excluding: excluding)
        } else {
            return await cleanseVisitEdge(with: otherItem, in: list, excluding: excluding)
        }
    }

    @TimelineActor
    private func cleanseTripEdge(with otherTrip: TimelineItem, in list: TimelineLinkedList, excluding: Set<LocomotionSample>) async -> LocomotionSample? {
        guard let trip else { return nil }

        guard let myActivityType = trip.activityType,
              let theirActivityType = otherTrip.trip?.activityType,
              myActivityType != theirActivityType else { return nil }

        guard let myEdge = self.edgeSample(withOtherItemId: otherTrip.id),
              let theirEdge = otherTrip.edgeSample(withOtherItemId: self.id),
              let myEdgeLocation = myEdge.location,
              let theirEdgeLocation = theirEdge.location else { return nil }

        let mySpeedIsSlow = myEdgeLocation.speed < TimelineProcessor.maximumModeShiftSpeed
        let theirSpeedIsSlow = theirEdgeLocation.speed < TimelineProcessor.maximumModeShiftSpeed

        if mySpeedIsSlow != theirSpeedIsSlow { return nil }

        if !excluding.contains(theirEdge), theirEdge.classifiedActivityType == myActivityType {
            // TODO: Implement add method
            // self.add(theirEdge)
            return theirEdge
        }

        return nil
    }

    @TimelineActor
    private func cleanseVisitEdge(with otherTrip: TimelineItem, in list: TimelineLinkedList, excluding: Set<LocomotionSample>) async -> LocomotionSample? {
        guard let visit else { return nil }

        guard let visitEdge = self.edgeSample(withOtherItemId: otherTrip.id),
              let visitEdgeNext = self.secondToEdgeSample(withOtherItemId: otherTrip.id),
              let tripEdge = otherTrip.edgeSample(withOtherItemId: self.id),
              let tripEdgeNext = otherTrip.secondToEdgeSample(withOtherItemId: self.id),
              let tripEdgeLocation = tripEdge.location,
              let tripEdgeNextLocation = tripEdgeNext.location else { return nil }

        let tripEdgeIsInside = visit.contains(tripEdgeLocation)
        let tripEdgeNextIsInside = visit.contains(tripEdgeNextLocation)

        if !excluding.contains(tripEdge), tripEdgeIsInside && tripEdgeNextIsInside {
            // TODO: Implement add method
            // self.add(pathEdge)
            return tripEdge
        }

        let edgeNextDuration = abs(visitEdge.date.timeIntervalSince(visitEdgeNext.date))
        if edgeNextDuration > 120 { return nil }

        if !excluding.contains(visitEdge), !tripEdgeIsInside {
            // TODO: Implement add method
            // trip.add(visitEdge)
            return visitEdge
        }

        return nil
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
