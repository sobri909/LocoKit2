//
//  TimelineProcessor+EdgeCleansing.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 17/03/2025.
//

import Foundation
import GRDB

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
            Log.debug("TimelineProcessor.sanitiseEdges(for:) moved \(alreadyMoved.count) samples", subsystem: .timeline)
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
                    list.invalidate(itemId: itemId)
                    list.invalidate(itemId: previousItemId)
                }
            }

            if let nextItemId = item.base.nextItemId {
                if let moved = try await edgeSteal(forItemId: itemId, otherItemId: nextItemId, in: list, excluding: excluding.union(allMoved)) {
                    movedThisLoop.insert(moved)
                    list.invalidate(itemId: itemId)
                    list.invalidate(itemId: nextItemId)
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
        guard !item.locked && !otherItem.locked else { return nil }
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
              let visitEdgeLocation = visitEdge.location,
              let tripEdgeLocation = tripEdge.location,
              let tripEdgeNextLocation = tripEdgeNext.location else { return nil }

        // first attempt: try to move trip edge into visit
        if !excluding.contains(tripEdge) {
            // BIG-408: stationary edge samples are genuine visit time (correct arrival/departure),
            // so retain them readily (sd:2 ≈ the rendered visit circle). Moving samples stay
            // conservative (sd:1) so low-hAcc edge samples can't drag the visit centre. Each sample
            // gated on its own effective type (confirmed ?? classified).
            let tripEdgeIsInside = visit.contains(tripEdgeLocation, sd: tripEdge.activityType == .stationary ? 2 : 1)
            let tripEdgeNextIsInside = visit.contains(tripEdgeNextLocation, sd: tripEdgeNext.activityType == .stationary ? 2 : 1)

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

        // BIG-408: don't eject a visit-edge sample that still belongs to the visit by its own
        // type-threshold (stationary→sd:2, moving→sd:1). Keeps genuine stationary tails put +
        // avoids cascading them back out after the pull path absorbs them; wrongly-stationary
        // wakeup-launch samples still eject once they move beyond sd:2.
        if !excluding.contains(visitEdge), !visit.contains(tripEdgeLocation, sd: 1) {
            let visitEdgeBelongs = visit.contains(visitEdgeLocation, sd: visitEdge.activityType == .stationary ? 2 : 1)
            if !visitEdgeBelongs {
                try await visitEdge.assignTo(itemId: tripItem.id)
                return visitEdge
            }
        }


        return nil
    }

}
