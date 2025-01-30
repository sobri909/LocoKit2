//
//  TimelineProcessor+Edges.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation
import CoreLocation
import GRDB

@TimelineActor
extension TimelineProcessor {

    // MARK: - Edge cleansing

    static func sanitiseEdges(for list: TimelineLinkedList) async throws {
        var alreadyMoved: Set<LocomotionSample> = []
        var processedItemIds = Set<String>()

        for itemId in list.itemIds {
            if processedItemIds.contains(itemId) { continue }

            let moved = try await sanitiseEdges(forItemId: itemId, in: list, excluding: alreadyMoved)

            alreadyMoved.formUnion(moved)
            processedItemIds.insert(itemId)
        }

        if TimelineProcessor.debugLogging, !alreadyMoved.isEmpty {
            print("TimelineProcessor.sanitiseEdges(for:) moved \(alreadyMoved.count) samples")
        }
    }

    private static func sanitiseEdges(forItemId itemId: String, in list: TimelineLinkedList,
                                    excluding: Set<LocomotionSample> = []) async throws -> Set<LocomotionSample> {
        var allMoved: Set<LocomotionSample> = []
        let maximumEdgeSteals = 30

        while allMoved.count < maximumEdgeSteals {
            guard let item = await list.itemFor(itemId: itemId) else { break }

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

    private static func edgeSteal(forItemId itemId: String, otherItemId: String, in list: TimelineLinkedList,
                                excluding: Set<LocomotionSample>) async throws -> LocomotionSample? {
        guard let item = await list.itemFor(itemId: itemId),
              let otherItem = await list.itemFor(itemId: otherItemId) else {
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

    private static func edgeSteal(forTripItem tripItem: TimelineItem, otherTrip: TimelineItem, in list: TimelineLinkedList,
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
            try await otherEdge.assignTo(itemId: tripItem.id)
            return otherEdge
        }

        return nil
    }

    private static func edgeSteal(forVisitItem visitItem: TimelineItem, tripItem: TimelineItem, in list: TimelineLinkedList,
                                  excluding: Set<LocomotionSample>) async throws -> LocomotionSample? {
        guard visitItem.isVisit, let visit = visitItem.visit, tripItem.isTrip else { return nil }

        // check if items could theoretically merge
        guard try visitItem.isWithinMergeableDistance(of: tripItem) else { return nil }

        // sanity check: don't steal edges across large time gaps
        guard abs(visitItem.timeInterval(from: tripItem)) < .minutes(10) else { return nil }

        // get required edge samples
        guard let visitEdge = try visitItem.edgeSample(withOtherItemId: tripItem.id),
              let visitEdgeNext = try visitItem.secondToEdgeSample(withOtherItemId: tripItem.id),
              let tripEdge = try tripItem.edgeSample(withOtherItemId: visitItem.id),
              let tripEdgeNext = try tripItem.secondToEdgeSample(withOtherItemId: visitItem.id) else { return nil }

        // check for usable coordinates and get locations
        guard visitEdge.hasUsableCoordinate, visitEdgeNext.hasUsableCoordinate,
              tripEdge.hasUsableCoordinate, tripEdgeNext.hasUsableCoordinate,
              let tripEdgeLocation = tripEdge.location,
              let tripEdgeNextLocation = tripEdgeNext.location else { return nil }

        // first attempt: try to move trip edge into visit
        if !excluding.contains(tripEdge) {
            let tripEdgeIsInside = visit.contains(tripEdgeLocation, sd: 1) // experiment with smaller radius
            let tripEdgeNextIsInside = visit.contains(tripEdgeNextLocation, sd: 1)

            if tripEdgeIsInside && tripEdgeNextIsInside {
                try await tripEdge.assignTo(itemId: visitItem.id)
                return tripEdge
            }
        }

        // only attempt moving visit edge if moving trip edge failed
        let edgeNextDuration = abs(visitEdge.date.timeIntervalSince(visitEdgeNext.date))
        if edgeNextDuration > .minutes(2) { return nil }

        // Don't steal edge if it would make the visit invalid
        guard let visitSamples = visitItem.samples, visitSamples.count > 1 else { return nil }

        if !excluding.contains(visitEdge), !visit.contains(tripEdgeLocation, sd: 1) {
            try await visitEdge.assignTo(itemId: tripItem.id)
            return visitEdge
        }

        return nil
    }

    // MARK: - Edge healing

    private static let edgeHealingThreshold: TimeInterval = .minutes(15)

    static func healEdges(itemId: String) async throws {
        guard let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true) else {
            return
        }

        if item.deleted || item.disabled {
            return
        }

        guard let dateRange = item.dateRange else {
            return
        }

        // Check for full containment by another item first
        let container = try await Database.pool.read { db in
            try TimelineItem
                .itemRequest(includeSamples: false)
                .filter(Column("startDate") <= dateRange.start)
                .filter(Column("endDate") >= dateRange.end)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("source") == item.source)  // only merge same sources
                .filter(Column("id") != item.id)
                .fetchOne(db)
        }

        // if fully contained, transfer samples and delete
        if let container, let samples = item.samples {
            try await Database.pool.write { db in
                for var sample in samples {
                    try sample.updateChanges(db) {
                        $0.timelineItemId = container.id
                    }
                }
                var mutableItem = item
                try mutableItem.base.updateChanges(db) {
                    $0.deleted = true
                }
            }
            return
        }

        if item.base.previousItemId == nil {
            try await healPreviousEdge(of: item)
        }

        if item.base.nextItemId == nil {
            try await healNextEdge(of: item)
        }
    }

    private static func healPreviousEdge(of item: TimelineItem) async throws {
        guard let dateRange = item.dateRange else {
            return
        }

        // find nearest in window centered on our start date
        let nearest = try await Database.pool.read { [edgeHealingThreshold] db in
            try TimelineItem.itemRequest(includeSamples: false)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("id") != item.id)
                .filter(Column("endDate") >= dateRange.start - edgeHealingThreshold)
                .filter(Column("endDate") <= dateRange.start + edgeHealingThreshold)
                .annotated(with: SQL(sql: "ABS(strftime('%s', endDate) - strftime('%s', ?))",arguments: [dateRange.start]).forKey("gap"))
                .order(literal: "gap")
                .fetchOne(db)
        }

        if let nearest, let nearestEndDate = nearest.dateRange?.end {
            let gap = dateRange.start.timeIntervalSince(nearestEndDate)

            // check if nearest already has a next item
            if let currentNextId = nearest.base.nextItemId,
               let currentNext = try await TimelineItem.fetchItem(itemId: currentNextId, includeSamples: false) {
                let currentGap = currentNext.timeInterval(from: nearest)

                // only steal if we're closer
                if abs(gap) >= abs(currentGap) {
                    return
                }
            }

            if nearest.base.previousItemId == item.id {
                logger.info("healPreviousEdge() Rejecting potential circular reference", subsystem: .timeline)
                return
            }

            // we're either first or closer - take the edge
            try await Database.pool.write { db in
                var mutableItem = item
                try mutableItem.base.updateChanges(db) {
                    $0.previousItemId = nearest.id
                }
            }

        } else {
            logger.info("healPreviousEdge() No possible nearest item found", subsystem: .timeline)
        }
    }

    private static func healNextEdge(of item: TimelineItem) async throws {
        guard let dateRange = item.dateRange else {
            return
        }

        // find nearest in window centered on our end date
        let nearest = try await Database.pool.read { [edgeHealingThreshold] db in
            try TimelineItem.itemRequest(includeSamples: false)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("id") != item.id)
                .filter(Column("startDate") >= dateRange.end - edgeHealingThreshold)
                .filter(Column("startDate") <= dateRange.end + edgeHealingThreshold)
                .annotated(with: SQL(sql: "ABS(strftime('%s', startDate) - strftime('%s', ?))",arguments: [dateRange.end]).forKey("gap"))
                .order(literal: "gap")
                .fetchOne(db)
        }

        if let nearest, let nearestStartDate = nearest.dateRange?.start {
            let gap = nearestStartDate.timeIntervalSince(dateRange.end)

            // check if nearest already has a previous item
            if let currentPrevId = nearest.base.previousItemId,
               let currentPrev = try await TimelineItem.fetchItem(itemId: currentPrevId, includeSamples: false) {
                let currentGap = currentPrev.timeInterval(from: nearest)

                // only steal if we're closer
                if abs(gap) >= abs(currentGap) {
                    return
                }
            }

            if nearest.base.nextItemId == item.id {
                logger.info("healNextEdge() Rejecting potential circular reference", subsystem: .timeline)
                return
            }

            // we're either first or closer - take the edge
            try await Database.pool.write { db in
                var mutableItem = item
                try mutableItem.base.updateChanges(db) {
                    $0.nextItemId = nearest.id
                }
            }
            
        } else {
            logger.info("healNextEdge() No possible nearest item found", subsystem: .timeline)
        }
    }

    // MARK: - Db inconsistency fix
    // probably unnecessary / dead code, used only once to fix a bad state during development
    // but keeping it around... just in case

    static func sanitiseCircularReferences() async throws {
        // Find items with both edges pointing to the same item
        let circularItems = try await Database.pool.read { db in
            try TimelineItem
                .itemRequest(includeSamples: false)
                .filter(sql: """
                    nextItemId IS NOT NULL AND 
                    previousItemId IS NOT NULL AND
                    nextItemId = previousItemId
                    """)
                .fetchAll(db)
        }

        if !circularItems.isEmpty {
            logger.info("Breaking \(circularItems.count) circular edge references", subsystem: .timeline)

            // Break the cycles by nulling the next edge
            try await Database.pool.write { db in
                for var item in circularItems {
                    logger.info("Breaking circular reference on item: \(item.id) next/prev: \(item.base.nextItemId ?? "nil")", subsystem: .timeline)
                    try item.base.updateChanges(db) {
                        $0.nextItemId = nil
                    }
                }
            }
        }
    }

}
