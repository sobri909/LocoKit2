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
    
    static func createDataGapItem(between firstItem: TimelineItem, and secondItem: TimelineItem) async throws {
        guard let firstDateRange = firstItem.dateRange,
              let secondDateRange = secondItem.dateRange else {
            throw TimelineError.invalidItem("Missing date range")
        }
        
        let gapStart = firstDateRange.end
        let gapEnd = secondDateRange.start
        
        let startSample = LocomotionSample.dataGap(date: gapStart)
        let endSample = LocomotionSample.dataGap(date: gapEnd)
        
        try await Database.pool.write { db in
            // samples must exist in db before they can be used to create a timeline item
            try startSample.insert(db)
            try endSample.insert(db)
            
            let dbSamples = [startSample, endSample]
            
            var item = try TimelineItem.createItem(from: dbSamples, isVisit: false, db: db)
            try item.base.updateChanges(db) {
                $0.previousItemId = firstItem.id
                $0.nextItemId = secondItem.id
            }
        }
    }
}
