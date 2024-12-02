//
//  TimelineProcessor+Extraction.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation
import GRDB

@TimelineActor
extension TimelineProcessor {
    
    // MARK: - Item extraction

    @discardableResult
    public static func extractItem(for segment: ItemSegment, isVisit: Bool) async throws -> TimelineItem? {
        guard try await segment.validateIsContiguous() else {
            throw TimelineError.invalidSegment("Segment fails validateIsContiguous()")
        }

        // get overlapping items
        let overlappers = try await Database.pool.read { db in
            try TimelineItem
                .itemRequest(includeSamples: true)
                .filter(Column("deleted") == false && Column("disabled") == false)
                .filter(Column("endDate") > segment.dateRange.start && Column("startDate") < segment.dateRange.end)
                .order(Column("startDate").asc)
                .fetchAll(db)
        }

        var prevEdgesToBreak: [TimelineItem] = []
        var nextEdgesToBreak: [TimelineItem] = []
        var itemsToDelete: [TimelineItem] = []
        var itemsToHeal = overlappers.map { $0.id }

        // process overlapping items
        for item in overlappers {
            guard let itemRange = item.dateRange, let itemSamples = item.samples else { continue }

            // if item is entirely inside the segment (or identical to), delete the item
            if segment.dateRange.contains(itemRange) {
                itemsToDelete.append(item)
                continue
            }

            // break prev edges inside the segment's range
            if segment.dateRange.contains(itemRange.start) {
                prevEdgesToBreak.append(item)
            }

            // break next edges inside the segment's range
            if segment.dateRange.contains(itemRange.end) {
                nextEdgesToBreak.append(item)
            }

            // if segment is entirely inside the item (and not identical to), split the item
            if itemRange.start < segment.dateRange.start && itemRange.end > segment.dateRange.end {
                let afterSamples = itemSamples.filter { $0.date > segment.dateRange.end }
                nextEdgesToBreak.append(item)
                let afterItem = try await TimelineItem.createItem(from: afterSamples, isVisit: item.isVisit)
                itemsToHeal.append(afterItem.id)
            }
        }

        // create the new item
        let newItem = try await TimelineItem.createItem(from: segment.samples, isVisit: isVisit)
        itemsToHeal.append(newItem.id)

        // perform database operations
        try await Database.pool.write { [prevEdgesToBreak, nextEdgesToBreak, itemsToDelete] db in
            for var item in itemsToDelete {
                try item.base.updateChanges(db) {
                    $0.deleted = true
                }
            }
            for var item in prevEdgesToBreak {
                try item.base.updateChanges(db) {
                    $0.previousItemId = nil
                }
            }
            for var item in nextEdgesToBreak {
                try item.base.updateChanges(db) {
                    $0.nextItemId = nil
                }
            }
        }

        // update current item if necessary
        TimelineRecorder.highlander.updateCurrentItemId()

        // heal edges
        for itemId in itemsToHeal {
            do {
                try await healEdges(itemId: itemId)
            } catch {
                logger.error(error, subsystem: .database)
            }
        }

        TimelineRecorder.highlander.updateCurrentItemId()

        return newItem
    }
}
