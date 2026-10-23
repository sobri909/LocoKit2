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
        guard let fetched = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true) else {
            return
        }

        if fetched.deleted || fetched.disabled {
            return
        }

        // an edge whose item is deleted or missing is cleared first and then healed like a nil edge
        // (BIG-752): old data can carry one, and nothing else repairs it; the edge triggers only prevent
        // new ones. Cleared before the zombie check, so an empty item whose only edges dangle is a zombie.
        let (previousDangling, nextDangling) = try await Database.pool.read { db in
            func dangling(_ id: String?) throws -> Bool {
                guard let id else { return false }
                return try TimelineItemBase
                    .filter(TimelineItemBase.Columns.id == id)
                    .filter(TimelineItemBase.Columns.deleted == false)
                    .fetchCount(db) == 0
            }
            return (try dangling(fetched.base.previousItemId), try dangling(fetched.base.nextItemId))
        }
        var cleared = fetched
        if previousDangling || nextDangling {
            let which = [previousDangling ? "previous" : nil, nextDangling ? "next" : nil].compactMap { $0 }.joined(separator: " and ")
            Log.info("healEdges: \(fetched.debugShortId) has a \(which) edge to a deleted or missing item; clearing it (BIG-752)", subsystem: .timeline)
            try await Database.pool.write { db in
                var row = fetched
                try row.base.updateChanges(db) {
                    if previousDangling { $0.previousItemId = nil }
                    if nextDangling { $0.nextItemId = nil }
                }
            }
            if previousDangling { cleared.base.previousItemId = nil }
            if nextDangling { cleared.base.nextItemId = nil }
        }
        let item = cleared

        // detect and soft delete zombie items (empty with no edges)
        if (item.samples?.isEmpty ?? true) && item.base.previousItemId == nil && item.base.nextItemId == nil {
            // make sure it's not the current recording item
            if item.id != TimelineRecorder.currentItemId {
                Log.info("Soft deleting zombie item: \(item.debugShortId) (no samples, no edges)", subsystem: .timeline)
                
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
            let request = TimelineItem
                .itemBaseRequest(includeSamples: false)
                .filter { $0.startDate <= dateRange.start }
                .filter { $0.endDate >= dateRange.end }
                .filter { $0.deleted == false && $0.disabled == false }
                .filter { $0.id != item.id }
            return try request.asRequest(of: TimelineItem.self).fetchOne(db)
        }

        // if fully contained, transfer samples and delete (but not if locked)
        if let container, let samples = item.samples, !item.base.locked {
            // BIG-864: the containment move is the one path that empties an item with no keepness
            // check, so it gets a line in the log file
            Log.info("healEdges: \(item.debugShortId) (\(item.isVisit ? "visit" : "trip"), \(samples.count) samples, \(dateRange.start)…\(dateRange.end)) lies inside \(container.debugShortId) (\(container.isVisit ? "visit" : "trip"), \(String(describing: container.dateRange?.start))…\(String(describing: container.dateRange?.end))); moving its samples and deleting it", subsystem: .timeline)
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
            let request = TimelineItem
                .itemBaseRequest(includeSamples: false)
                .filter { $0.deleted == false && $0.disabled == false }
                .filter { $0.id != item.id }
                .filter { $0.endDate >= dateRange.start - searchWindow }
                .filter { $0.endDate <= dateRange.start + searchWindow }
                .annotated(with: SQL(sql: "ABS(strftime('%s', endDate) - strftime('%s', ?))",
                                    arguments: [dateRange.start]).forKey("gap"))
                .order(literal: "gap")
            return try request.asRequest(of: TimelineItem.self).fetchOne(db)
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
                Log.info("healPreviousEdge() Rejecting potential circular reference", subsystem: .timeline)
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
                Log.info("Created data gap between \(nearest.debugShortId) and \(item.debugShortId) (\(Int(abs(gap)))s)", subsystem: .timeline)
            }

        } else {
            Log.info("healPreviousEdge() No possible nearest item found", subsystem: .timeline)
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
            let request = TimelineItem
                .itemBaseRequest(includeSamples: false)
                .filter { $0.deleted == false && $0.disabled == false }
                .filter { $0.id != item.id }
                .filter { $0.startDate >= dateRange.end - searchWindow }
                .filter { $0.startDate <= dateRange.end + searchWindow }
                .annotated(with: SQL(sql: "ABS(strftime('%s', startDate) - strftime('%s', ?))",
                                    arguments: [dateRange.end]).forKey("gap"))
                .order(literal: "gap")
            return try request.asRequest(of: TimelineItem.self).fetchOne(db)
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
                Log.info("healNextEdge() Rejecting potential circular reference", subsystem: .timeline)
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
                Log.info("Created data gap between \(item.debugShortId) and \(nearest.debugShortId) (\(Int(abs(gap)))s)", subsystem: .timeline)
            }
            
        } else {
            Log.info("healNextEdge() No possible nearest item found", subsystem: .timeline)
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
            Log.info("Breaking \(circularItems.count) circular edge references", subsystem: .timeline)

            // break the cycles by nulling the next edge
            try await Database.pool.write { db in
                for var item in circularItems {
                    Log.info("Breaking circular reference on item: \(item.id) next/prev: \(item.base.nextItemId ?? "nil")", subsystem: .timeline)
                    try item.base.updateChanges(db) {
                        $0.nextItemId = nil
                    }
                }
            }
        }
    }

}
