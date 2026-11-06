//
//  TimelineProcessor+DataGaps.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 16/03/2025.
//

import Foundation
import CoreLocation
import GRDB

@TimelineActor
extension TimelineProcessor {
    
    // MARK: - Data Gap Creation
    
    /// Writes a data gap item between `firstItem` and `secondItem` and links all three. Returns `false`,
    /// writing nothing, when either item's edge has moved since the caller read it (BIG-793): two edge
    /// heals can decide the same gap from reads that completed before either wrote, since the actor only
    /// serialises between suspension points, and the second write would create a twin that the edge
    /// triggers then leave dangling. The writer queue is serial, so a re-read inside the write sees the
    /// other heal's edges. A changed edge is compared against the caller's read, not against nil, so a
    /// heal that read the nearest item's existing farther neighbour (the steal case) still proceeds.
    @discardableResult
    static func createDataGapItem(between firstItem: TimelineItem, and secondItem: TimelineItem) async throws -> Bool {
        // block data gap creation during partial import to prevent corruption
        try await ImportState.guardNotPartialImport()

        guard let firstDateRange = firstItem.dateRange,
              let secondDateRange = secondItem.dateRange else {
            throw TimelineError.invalidItem("Missing date range")
        }
        
        let gapStart = firstDateRange.end
        let gapEnd = secondDateRange.start
        
        let startSample = LocomotionSample.dataGap(date: gapStart)
        let endSample = LocomotionSample.dataGap(date: gapEnd)
        
        return try await Database.pool.write { db in
            // BIG-793: re-read both edges on the writer queue; bail if another heal has already moved them
            guard let firstFresh = try TimelineItemBase.fetchOne(db, key: firstItem.id),
                  let secondFresh = try TimelineItemBase.fetchOne(db, key: secondItem.id),
                  !firstFresh.deleted, !secondFresh.deleted, !firstFresh.disabled, !secondFresh.disabled else {
                Log.info("createDataGapItem: an endpoint is deleted, disabled or missing; not creating the gap (BIG-793)", subsystem: .timeline)
                return false
            }
            if firstFresh.nextItemId != firstItem.base.nextItemId || secondFresh.previousItemId != secondItem.base.previousItemId {
                let short: (String?) -> String = { $0.map { String($0.prefix(8)) } ?? "nil" }
                Log.info("createDataGapItem: edges moved since the heal's read (\(firstItem.debugShortId).next \(short(firstItem.base.nextItemId)) → \(short(firstFresh.nextItemId)), \(secondItem.debugShortId).previous \(short(secondItem.base.previousItemId)) → \(short(secondFresh.previousItemId))); another heal got there first, not creating a twin (BIG-793)", subsystem: .timeline)
                return false
            }

            // samples must exist in db before they can be used to create a timeline item
            try startSample.insert(db)
            try endSample.insert(db)
            
            let dbSamples = [startSample, endSample]
            
            var item = try TimelineItem.createItem(from: dbSamples, isVisit: false, db: db)
            try item.base.updateChanges(db) {
                $0.previousItemId = firstItem.id
                $0.nextItemId = secondItem.id
            }
            return true
        }
    }
}
