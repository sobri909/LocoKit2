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
    public static func extractVisit(for segment: ItemSegment, placeId: String, confirmedPlace: Bool) async throws -> TimelineItem? {
        return try await extractItem(for: segment, isVisit: true, placeId: placeId, confirmedPlace: confirmedPlace)
    }
    
    @discardableResult
    public static func extractVisit(for segment: ItemSegment, customTitle: String) async throws -> TimelineItem? {
        return try await extractItem(for: segment, isVisit: true, customTitle: customTitle)
    }

    @discardableResult
    public static func extractItem(
        for segment: ItemSegment,
        isVisit: Bool,
        placeId: String? = nil,
        confirmedPlace: Bool = true,
        customTitle: String? = nil
    ) async throws -> TimelineItem? {
        guard let handle = await OperationRegistry.startOperation(.timeline, operation: "TimelineProcessor.extractItem(from:isVisit:placeId:confirmedPlace:customTitle:)", objectKey: segment.id) else { 
            return nil 
        }
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        // TODO: think through a way to bring this back, but without the breakage
        // guard try await segment.validateIsContiguous() else {
        //     throw TimelineError.invalidSegment("Segment fails validateIsContiguous()")
        // }

        // get overlapping items
        let overlappers = try await Database.pool.uncancellableRead { db in
            let request = TimelineItem
                .itemBaseRequest(includeSamples: true)
                .filter { $0.deleted == false && $0.disabled == false }
                .filter { $0.endDate > segment.dateRange.start && $0.startDate < segment.dateRange.end }
                .order(\.startDate.asc)
            return try request.asRequest(of: TimelineItem.self).fetchAll(db)
        }

        let (newItem, itemsToHeal) = try await Database.pool.uncancellableWrite { db in
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
                    var afterItem = try TimelineItem.createItem(from: afterSamples, isVisit: item.isVisit, db: db)
                    try afterItem.copyMetadata(from: item, db: db)
                    itemsToHeal.append(afterItem.id)
                }
            }

            // break edges
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

            // create the new item
            var newItem = try TimelineItem.createItem(from: segment.samples, isVisit: isVisit, db: db)
            itemsToHeal.append(newItem.id)

            // assign place or custom title if provided
            if isVisit {
                if let placeId {
                    try newItem.visit?.updateChanges(db) {
                        $0.placeId = placeId
                        $0.confirmedPlace = confirmedPlace
                        if confirmedPlace {
                            $0.setUncertainty(false)
                        }
                    }

                    // mark place stale so its stats get updated
                    try Place
                        .filter { $0.id == placeId }
                        .updateAll(db) { $0.isStale.set(to: true) }

                } else if let customTitle {
                    try newItem.visit?.updateChanges(db) {
                        $0.customTitle = customTitle
                        $0.placeId = nil
                        $0.confirmedPlace = false
                        $0.setUncertainty(true)
                    }
                }
            }

            // delete items
            for var item in itemsToDelete {
                try item.base.updateChanges(db) {
                    $0.deleted = true
                }
            }

            return (newItem, itemsToHeal)
        }

        // update current item if necessary
        TimelineRecorder.updateCurrentItemId()

        // heal edges
        for itemId in itemsToHeal {
            do {
                try await healEdges(itemId: itemId)
            } catch {
                Log.error(error, subsystem: .database)
            }
        }

        // Process all affected items after healing edges
        await process(itemIds: itemsToHeal)

        return newItem
    }
    
}
