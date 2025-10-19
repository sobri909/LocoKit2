//
//  TimelineProcessor+EdgeHealing.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation
import CoreLocation
import GRDB

@TimelineActor
extension TimelineProcessor {

    static let edgeHealingThreshold: TimeInterval = .minutes(15)

    static func healEdges(itemId: String) async throws {
        guard let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true) else {
            return
        }

        if item.deleted || item.disabled {
            return
        }

        // detect and soft delete zombie items (empty with no edges)
        if (item.samples?.isEmpty ?? true) && item.base.previousItemId == nil && item.base.nextItemId == nil {
            // make sure it's not the current recording item
            if item.id != TimelineRecorder.currentItemId {
                logger.info("Soft deleting zombie item: \(item.debugShortId) (no samples, no edges)", subsystem: .timeline)
                
                try await Database.pool.write { db in
                    var mutableItem = item
                    try mutableItem.base.updateChanges(db) {
                        $0.deleted = true
                    }
                }
                return
            }
        }

        guard let dateRange = item.dateRange else {
            return
        }

        // check for full containment by another item first
        let container = try await Database.pool.read { db in
            try TimelineItem
                .itemRequest(includeSamples: false)
                .filter(Column("startDate") <= dateRange.start)
                .filter(Column("endDate") >= dateRange.end)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("id") != item.id)
                .fetchOne(db)
        }

        // if fully contained, transfer samples and delete (but not if locked)
        if let container, let samples = item.samples, !item.base.locked {
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

        // handle previous and next edges, with integrated data gap handling
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

        // use a wider search window to find nearest items regardless of threshold
        let searchWindow: TimeInterval = .hours(24)
        
        // find nearest item within a larger window
        let nearest = try await Database.pool.read { db in
            try TimelineItem.itemRequest(includeSamples: false)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("id") != item.id)
                .filter(Column("endDate") >= dateRange.start - searchWindow)
                .filter(Column("endDate") <= dateRange.start + searchWindow)
                .annotated(with: SQL(sql: "ABS(strftime('%s', endDate) - strftime('%s', ?))",
                                    arguments: [dateRange.start]).forKey("gap"))
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

            // connect directly when items are temporally close
            if abs(gap) <= edgeHealingThreshold {
                try await Database.pool.write { db in
                    var mutableItem = item
                    try mutableItem.base.updateChanges(db) {
                        $0.previousItemId = nearest.id
                    }
                }

            } else {
                // represent longer gaps with explicit data gap items
                try await createDataGapItem(between: nearest, and: item)
                logger.info("Created data gap between \(nearest.debugShortId) and \(item.debugShortId) (\(Int(abs(gap)))s)", subsystem: .timeline)
            }

        } else {
            logger.info("healPreviousEdge() No possible nearest item found", subsystem: .timeline)
        }
    }

    private static func healNextEdge(of item: TimelineItem) async throws {
        guard let dateRange = item.dateRange else {
            return
        }

        // use a wider search window to find nearest items regardless of threshold
        let searchWindow: TimeInterval = .hours(24)
        
        // find nearest item within a larger window
        let nearest = try await Database.pool.read { db in
            try TimelineItem.itemRequest(includeSamples: false)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("id") != item.id)
                .filter(Column("startDate") >= dateRange.end - searchWindow)
                .filter(Column("startDate") <= dateRange.end + searchWindow)
                .annotated(with: SQL(sql: "ABS(strftime('%s', startDate) - strftime('%s', ?))",
                                    arguments: [dateRange.end]).forKey("gap"))
                .order(literal: "gap")
                .fetchOne(db)
        }

        if let nearest, let nearestStartDate = nearest.dateRange?.start {
            let gap = nearestStartDate.timeIntervalSince(dateRange.end)

            // check if nearest already has a previous item
            if let currentPrevId = nearest.base.previousItemId,
               let currentPrev = try await TimelineItem.fetchItem(itemId: currentPrevId, includeSamples: false) {
                let currentGap = nearest.timeInterval(from: currentPrev)

                // only steal if we're closer
                if abs(gap) >= abs(currentGap) {
                    return
                }
            }

            if nearest.base.nextItemId == item.id {
                logger.info("healNextEdge() Rejecting potential circular reference", subsystem: .timeline)
                return
            }

            // connect directly when items are temporally close
            if abs(gap) <= edgeHealingThreshold {
                try await Database.pool.write { db in
                    var mutableItem = item
                    try mutableItem.base.updateChanges(db) {
                        $0.nextItemId = nearest.id
                    }
                }

            } else {
                // represent longer gaps with explicit data gap items
                try await createDataGapItem(between: item, and: nearest)
                logger.info("Created data gap between \(item.debugShortId) and \(nearest.debugShortId) (\(Int(abs(gap)))s)", subsystem: .timeline)
            }
            
        } else {
            logger.info("healNextEdge() No possible nearest item found", subsystem: .timeline)
        }
    }

    // MARK: - Db inconsistency fix
    // probably unnecessary / dead code, used only once to fix a bad state during development
    // but keeping it around... just in case

    static func sanitiseCircularReferences() async throws {
        // find items with both edges pointing to the same item
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

            // break the cycles by nulling the next edge
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
