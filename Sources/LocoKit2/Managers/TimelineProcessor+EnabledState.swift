//
//  TimelineProcessor+EnabledState.swift
//  LocoKit2
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import GRDB

@TimelineActor
extension TimelineProcessor {

    /// Enable a disabled item, handling overlapping active items via preserve-on-disable pattern
    public static func enableItem(itemId: String) async throws {
        // fetch target item (the disabled item we're enabling)
        guard let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true) else {
            logger.error("enableItem(): Item not found: \(itemId)", subsystem: .timeline)
            return
        }

        guard item.disabled else {
            logger.info("enableItem(): Item already enabled: \(item.debugShortId)", subsystem: .timeline)
            return
        }

        guard let dateRange = item.dateRange else {
            logger.error("enableItem(): Item has no date range: \(item.debugShortId)", subsystem: .timeline)
            return
        }

        // query overlapping active items
        let overlappingItems = try await Database.pool.read { db in
            let request = TimelineItem
                .itemBaseRequest(includeSamples: true)
                .filter { $0.deleted == false && $0.disabled == false }
                .filter { $0.id != itemId }
                .filter { $0.startDate < dateRange.end && $0.endDate > dateRange.start }
            return try request.asRequest(of: TimelineItem.self).fetchAll(db)
        }

        try await Database.pool.write { db in
            // case 1: no overlaps - simple enable
            if overlappingItems.isEmpty {
                // enable item (trigger auto-syncs samples)
                var mutableItem = item
                try mutableItem.base.updateChanges(db) {
                    $0.disabled = false
                }

                logger.info("enableItem(): Enabled \(item.debugShortId) (no overlaps)", subsystem: .timeline)
                return
            }

            // handle overlapping items via preserve-on-disable pattern
            for overlappingItem in overlappingItems {
                guard let overlappingRange = overlappingItem.dateRange else { continue }

                // case 2: workout completely covers the overlapping item
                if dateRange.start <= overlappingRange.start && dateRange.end >= overlappingRange.end {
                    // disable item (trigger auto-syncs samples)
                    var mutableOverlapping = overlappingItem
                    try mutableOverlapping.base.updateChanges(db) {
                        $0.disabled = true
                    }

                    logger.info("enableItem(): Disabled overlapping item \(overlappingItem.debugShortId) (full cover)", subsystem: .timeline)
                    continue
                }

                // partial overlap cases require splitting
                guard let overlappingSamples = overlappingItem.samples else { continue }

                // case 3: workout overlaps start of item (split off trailing portion)
                if dateRange.start <= overlappingRange.start && dateRange.end < overlappingRange.end {
                    // disable item (trigger auto-syncs samples)
                    var mutableOverlapping = overlappingItem
                    try mutableOverlapping.base.updateChanges(db) {
                        $0.disabled = true
                    }

                    // create new item for trailing portion (after workout ends)
                    let trailingSamples = overlappingSamples.filter { $0.date >= dateRange.end }
                    if !trailingSamples.isEmpty {
                        let newItemId = try createSplitItem(from: overlappingItem, withSamples: trailingSamples, db: db)
                        logger.info("enableItem(): Created trailing split \(String(newItemId.split(separator: "-")[0])) from \(overlappingItem.debugShortId)", subsystem: .timeline)
                    }

                    logger.info("enableItem(): Disabled overlapping item \(overlappingItem.debugShortId) (start overlap)", subsystem: .timeline)
                    continue
                }

                // case 4: workout overlaps end of item (split off leading portion)
                if dateRange.start > overlappingRange.start && dateRange.end >= overlappingRange.end {
                    // disable item (trigger auto-syncs samples)
                    var mutableOverlapping = overlappingItem
                    try mutableOverlapping.base.updateChanges(db) {
                        $0.disabled = true
                    }

                    // create new item for leading portion (before workout starts)
                    let leadingSamples = overlappingSamples.filter { $0.date < dateRange.start }
                    if !leadingSamples.isEmpty {
                        let newItemId = try createSplitItem(from: overlappingItem, withSamples: leadingSamples, db: db)
                        logger.info("enableItem(): Created leading split \(String(newItemId.split(separator: "-")[0])) from \(overlappingItem.debugShortId)", subsystem: .timeline)
                    }

                    logger.info("enableItem(): Disabled overlapping item \(overlappingItem.debugShortId) (end overlap)", subsystem: .timeline)
                    continue
                }

                // case 5: workout in middle of item (split off both leading and trailing portions)
                if dateRange.start > overlappingRange.start && dateRange.end < overlappingRange.end {
                    // disable item (trigger auto-syncs samples)
                    var mutableOverlapping = overlappingItem
                    try mutableOverlapping.base.updateChanges(db) {
                        $0.disabled = true
                    }

                    // create new item for leading portion (before workout starts)
                    let leadingSamples = overlappingSamples.filter { $0.date < dateRange.start }
                    if !leadingSamples.isEmpty {
                        let leadingId = try createSplitItem(from: overlappingItem, withSamples: leadingSamples, db: db)
                        logger.info("enableItem(): Created leading split \(String(leadingId.split(separator: "-")[0])) from \(overlappingItem.debugShortId)", subsystem: .timeline)
                    }

                    // create new item for trailing portion (after workout ends)
                    let trailingSamples = overlappingSamples.filter { $0.date >= dateRange.end }
                    if !trailingSamples.isEmpty {
                        let trailingId = try createSplitItem(from: overlappingItem, withSamples: trailingSamples, db: db)
                        logger.info("enableItem(): Created trailing split \(String(trailingId.split(separator: "-")[0])) from \(overlappingItem.debugShortId)", subsystem: .timeline)
                    }

                    logger.info("enableItem(): Disabled overlapping item \(overlappingItem.debugShortId) (middle overlap)", subsystem: .timeline)
                    continue
                }
            }

            // enable target item (trigger auto-syncs samples)
            var mutableItem = item
            try mutableItem.base.updateChanges(db) {
                $0.disabled = false
            }

            logger.info("enableItem(): Enabled \(item.debugShortId) with overlaps handled", subsystem: .timeline)
        }

        // trigger edge healing to reconnect the timeline
        await processFrom(itemId: itemId)
    }

    /// Disable an enabled item, restoring any previously disabled overlapping items
    public static func disableItem(itemId: String) async throws {
        // fetch target item (the enabled item we're disabling)
        guard let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true) else {
            logger.error("disableItem(): Item not found: \(itemId)", subsystem: .timeline)
            return
        }

        guard !item.disabled else {
            logger.info("disableItem(): Item already disabled: \(item.debugShortId)", subsystem: .timeline)
            return
        }

        guard let dateRange = item.dateRange else {
            logger.error("disableItem(): Item has no date range: \(item.debugShortId)", subsystem: .timeline)
            return
        }

        let reenabledItemIds = try await Database.pool.write { db -> [String] in
            // disable item (trigger auto-syncs samples)
            var mutableItem = item
            try mutableItem.base.updateChanges(db) {
                $0.disabled = true
            }

            logger.info("disableItem(): Disabled \(item.debugShortId)", subsystem: .timeline)

            // find overlapping disabled items that were previously hidden by this item
            let disabledRequest = TimelineItem
                .itemBaseRequest(includeSamples: true)
                .filter { $0.deleted == false && $0.disabled == true }
                .filter { $0.id != itemId }
                .filter { $0.startDate < dateRange.end && $0.endDate > dateRange.start }
            let overlappingDisabledItems = try disabledRequest.asRequest(of: TimelineItem.self).fetchAll(db)

            // re-enable those items (trigger auto-syncs samples)
            var itemIds: [String] = []
            for overlappingItem in overlappingDisabledItems {
                var mutableOverlapping = overlappingItem
                try mutableOverlapping.base.updateChanges(db) {
                    $0.disabled = false
                }

                logger.info("disableItem(): Re-enabled \(overlappingItem.debugShortId)", subsystem: .timeline)
                itemIds.append(overlappingItem.id)
            }

            return itemIds
        }

        // trigger edge healing and merge processing for re-enabled items
        if !reenabledItemIds.isEmpty {
            await process(itemIds: reenabledItemIds)
        }
    }

    // MARK: - Helpers

    /// Create a new enabled item from a portion of an existing item's samples
    /// Copies all metadata from the original item to preserve Place assignments, custom titles, etc.
    nonisolated private static func createSplitItem(
        from originalItem: TimelineItem,
        withSamples samples: [LocomotionSample],
        db: GRDB.Database
    ) throws -> String {
        // create new base with same type and source as original
        var base = TimelineItemBase(isVisit: originalItem.isVisit)
        base.source = originalItem.source
        base.sourceVersion = originalItem.base.sourceVersion
        base.disabled = false  // split items are always enabled
        base.locked = originalItem.locked  // preserve locked state

        let visit: TimelineItemVisit?
        let trip: TimelineItemTrip?

        if originalItem.isVisit {
            var newVisit = TimelineItemVisit(itemId: base.id, samples: samples)
            // copy metadata from original visit
            if let originalVisit = originalItem.visit {
                newVisit?.copyMetadata(from: originalVisit)
            }
            visit = newVisit
            trip = nil

        } else {
            var newTrip = TimelineItemTrip(itemId: base.id, samples: samples)
            // copy metadata from original trip
            if let originalTrip = originalItem.trip {
                newTrip.confirmedActivityType = originalTrip.confirmedActivityType
                newTrip.uncertainActivityType = originalTrip.uncertainActivityType
            }
            trip = newTrip
            visit = nil
        }

        // insert new item structures
        try base.insert(db)
        try visit?.insert(db)
        try trip?.insert(db)

        // reassign samples to new item and enable them
        // use batch update to avoid updateChanges() comparing in-memory state
        let sampleIds = samples.map(\.id)
        try LocomotionSample
            .filter { sampleIds.contains($0.id) }
            .updateAll(db, [
                LocomotionSample.Columns.timelineItemId.set(to: base.id),
                LocomotionSample.Columns.disabled.set(to: false)
            ])

        return base.id
    }

}
