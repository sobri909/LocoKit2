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
