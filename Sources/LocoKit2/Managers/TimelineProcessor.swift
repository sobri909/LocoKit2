//
//  TimelineProcessor.swift
//
//
//  Created by Matt Greenfield on 6/6/24.
//

import Foundation
import CoreLocation
import GRDB

@TimelineActor
public final class TimelineProcessor {

    public static let highlander = TimelineProcessor()

    public static let debugLogging = true
    
    public static let maximumModeShiftSpeed = CLLocationSpeed(kmh: 2)

    private let maxProcessingListSize = 21
    private let maximumPotentialMergesInProcessingLoop = 10

    public func processFrom(itemId: String) async {
        do {
            guard let list = try await processingList(fromItemId: itemId) else { return }

            if let results = await process(list) {
                await processFrom(itemId: results.kept.id)
            }
            
        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

    public func process(_ list: TimelineLinkedList) async -> MergeResult? {
        do {
            try await sanitiseEdges(for: list)

            let merges = try await collectPotentialMerges(for: list)
                .sorted { $0.score.rawValue > $1.score.rawValue }

            // find the highest scoring valid merge
            guard let winningMerge = merges.first, winningMerge.score != .impossible else {
                return nil
            }

            return await winningMerge.doIt()

        } catch {
            logger.error(error, subsystem: .timeline)
            return nil
        }
    }

    // MARK: - Private

    private init() {}

    private func processingList(fromItemId: String) async throws -> TimelineLinkedList? {
        guard let list = await TimelineLinkedList(fromItemId: fromItemId) else { return nil }

        // collect items before seedItem, up to two keepers
        var previousKeepers = 0
        var workingItem = list.seedItem
        while previousKeepers < 2, list.timelineItems.count < maxProcessingListSize, let previous = await workingItem.previousItem(in: list) {
            if try previous.isWorthKeeping { previousKeepers += 1 }
            workingItem = previous
        }

        // collect items after seedItem, up to two keepers
        var nextKeepers = 0
        workingItem = list.seedItem
        while nextKeepers < 2, list.timelineItems.count < maxProcessingListSize, let next = await workingItem.nextItem(in: list) {
            if try next.isWorthKeeping { nextKeepers += 1 }
            workingItem = next
        }

        return list
    }

    // MARK: - Merge collating

    private func collectPotentialMerges(for list: TimelineLinkedList) async throws -> [Merge] {
        var merges: Set<Merge> = []

        for workingItem in list.timelineItems.values {
            if shouldStopCollecting(merges) {
                break
            }

            await collectAdjacentMerges(for: workingItem, in: list, into: &merges)
            try await collectBetweenerMerges(for: workingItem, in: list, into: &merges)
            try await collectBridgeMerges(for: workingItem, in: list, into: &merges)
        }

        return Array(merges)
    }

    private func shouldStopCollecting(_ merges: Set<Merge>) -> Bool {
        merges.count >= maximumPotentialMergesInProcessingLoop && merges.first(where: { $0.score != .impossible }) != nil
    }

    private func collectAdjacentMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async {
        if let next = await item.nextItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: next, in: list))
            merges.insert(await Merge(keeper: next, deadman: item, in: list))
        }

        if let previous = await item.previousItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: previous, in: list))
            merges.insert(await Merge(keeper: previous, deadman: item, in: list))
        }
    }

    private func collectBetweenerMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async throws {
        if let next = await item.nextItem(in: list), try !item.isDataGap, try next.keepnessScore < item.keepnessScore {
            if let nextNext = await next.nextItem(in: list), try !nextNext.isDataGap, try nextNext.keepnessScore > next.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: next, deadman: nextNext, in: list))
                merges.insert(await Merge(keeper: nextNext, betweener: next, deadman: item, in: list))
            }
        }

        if let previous = await item.previousItem(in: list), try !item.isDataGap, try previous.keepnessScore < item.keepnessScore {
            if let prevPrev = await previous.previousItem(in: list), try !prevPrev.isDataGap, try prevPrev.keepnessScore > previous.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: previous, deadman: prevPrev, in: list))
                merges.insert(await Merge(keeper: prevPrev, betweener: previous, deadman: item, in: list))
            }
        }
    }

    private func collectBridgeMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async throws {
        guard let previous = await item.previousItem(in: list),
              let next = await item.nextItem(in: list),
              previous.source == item.source,
              next.source == item.source,
              try previous.keepnessScore > item.keepnessScore,
              try next.keepnessScore > item.keepnessScore,
              try !previous.isDataGap,
              try !next.isDataGap
        else {
            return
        }

        merges.insert(await Merge(keeper: previous, betweener: item, deadman: next, in: list))
        merges.insert(await Merge(keeper: next, betweener: item, deadman: previous, in: list))
    }

    // MARK: - Edge cleansing

    private var alreadyMovedSamples: Set<LocomotionSample> = []

    private func sanitiseEdges(for list: TimelineLinkedList) async throws {
        var allMoved: Set<LocomotionSample> = []
        var processedItemIds = Set<String>()

        for itemId in list.timelineItems.keys {
            if processedItemIds.contains(itemId) { continue }

            let moved = try await sanitiseEdges(forItemId: itemId, in: list, excluding: alreadyMovedSamples)

            allMoved.formUnion(moved)
            processedItemIds.insert(itemId)
        }

        if TimelineProcessor.debugLogging, !allMoved.isEmpty {
            logger.debug("sanitiseEdges() moved \(allMoved.count) samples")
        }

        alreadyMovedSamples = allMoved
    }

    private func sanitiseEdges(forItemId itemId: String, in list: TimelineLinkedList,
                               excluding: Set<LocomotionSample> = []) async throws -> Set<LocomotionSample> {
        var allMoved: Set<LocomotionSample> = []
        let maximumEdgeSteals = 30

        while allMoved.count < maximumEdgeSteals {
            guard let item = list.timelineItems[itemId] else { break }

            var movedThisLoop: Set<LocomotionSample> = []

            if let previousItemId = item.base.previousItemId {
                if let moved = try await edgeSteal(forItemId: itemId, otherItemId: previousItemId, in: list, excluding: excluding.union(allMoved)) {
                    movedThisLoop.insert(moved)
                }
            }

            if let nextItemId = item.base.nextItemId {
                if let moved = try await edgeSteal(forItemId: itemId, otherItemId: nextItemId, in: list, excluding: excluding.union(allMoved)) {
                    movedThisLoop.insert(moved)
                }
            }

            if movedThisLoop.isEmpty { break }

            allMoved.formUnion(movedThisLoop)
        }

        return allMoved
    }

    private func edgeSteal(forItemId itemId: String, otherItemId: String, in list: TimelineLinkedList,
                             excluding: Set<LocomotionSample>) async throws -> LocomotionSample? {
        guard let item = list.timelineItems[itemId],
              let otherItem = list.timelineItems[otherItemId] else {
            return nil
        }

        // we only cleanse Trip edges (ie Visit-Trip or Trip-Trip)
        guard otherItem.isTrip else { return nil }

        guard !item.deleted && !otherItem.deleted else { return nil }
        guard item.source == otherItem.source else { return nil } // no edge stealing between different data sources
        guard try item.isWithinMergeableDistance(of: otherItem) else { return nil }
        guard item.timeInterval(from: otherItem) < .minutes(10) else { return nil } // 10 mins seems like a lot?

        if item.isTrip {
            return try await edgeSteal(forTripItem: item, otherTrip: otherItem, in: list, excluding: excluding)
        } else {
            return try await edgeSteal(forVisitItem: item, tripItem: otherItem, in: list, excluding: excluding)
        }
    }

    private func edgeSteal(forTripItem tripItem: TimelineItem, otherTrip: TimelineItem, in list: TimelineLinkedList,
                                 excluding: Set<LocomotionSample>) async throws -> LocomotionSample? {
        guard let trip = tripItem.trip, otherTrip.isTrip else { return nil }

        guard let activityType = trip.activityType,
              let otherActivityType = otherTrip.trip?.activityType,
              activityType != otherActivityType else { return nil }

        guard let edge = try tripItem.edgeSample(withOtherItemId: otherTrip.id),
              let otherEdge = try otherTrip.edgeSample(withOtherItemId: tripItem.id),
              let edgeLocation = edge.location,
              let otherEdgeLocation = otherEdge.location else { return nil }

        let speedIsSlow = edgeLocation.speed < TimelineProcessor.maximumModeShiftSpeed
        let otherSpeedIsSlow = otherEdgeLocation.speed < TimelineProcessor.maximumModeShiftSpeed

        if speedIsSlow != otherSpeedIsSlow { return nil }

        if !excluding.contains(otherEdge), otherEdge.classifiedActivityType == activityType {
            try await moveSample(otherEdge, to: tripItem.id)
            return otherEdge
        }

        return nil
    }

    private func edgeSteal(forVisitItem visitItem: TimelineItem, tripItem: TimelineItem, in list: TimelineLinkedList,
                             excluding: Set<LocomotionSample>) async throws -> LocomotionSample? {
        guard let visit = visitItem.visit, tripItem.isTrip else { return nil }

        guard let visitEdge = try visitItem.edgeSample(withOtherItemId: tripItem.id),
              let visitEdgeNext = try visitItem.secondToEdgeSample(withOtherItemId: tripItem.id),
              let tripEdge = try tripItem.edgeSample(withOtherItemId: visitItem.id),
              let tripEdgeNext = try tripItem.secondToEdgeSample(withOtherItemId: visitItem.id),
              let tripEdgeLocation = tripEdge.location,
              let tripEdgeNextLocation = tripEdgeNext.location else { return nil }

        let tripEdgeIsInside = visit.contains(tripEdgeLocation)
        let tripEdgeNextIsInside = visit.contains(tripEdgeNextLocation)

        if !excluding.contains(tripEdge), tripEdgeIsInside && tripEdgeNextIsInside {
            try await moveSample(tripEdge, to: tripItem.id)
            return tripEdge
        }

        let edgeNextDuration = abs(visitEdge.date.timeIntervalSince(visitEdgeNext.date))
        if edgeNextDuration > 120 { return nil }

        if !excluding.contains(visitEdge), !tripEdgeIsInside {
            try await moveSample(visitEdge, to: tripItem.id)
            return visitEdge
        }

        return nil
    }

    private func moveSample(_ sample: LocomotionSample, to destinationItemId: String) async throws {
        try await Database.pool.write { db in
            var mutableSample = sample
            try mutableSample.updateChanges(db) {
                $0.timelineItemId = destinationItemId
            }
        }
    }

}
