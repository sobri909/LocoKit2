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
    
    // MARK: - Data Gap Processing
    
    static func processDataGaps(for itemId: String) async throws {
        guard let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true),
              !item.deleted && !item.disabled else {
            return
        }
        
        try await checkDataGapWithNextItem(for: item)
        try await checkDataGapWithPreviousItem(for: item)
    }
    
    private static func checkDataGapWithNextItem(for item: TimelineItem) async throws {
        guard let nextItemId = item.base.nextItemId,
              !nextItemId.isEmpty,
              let nextItem = try await TimelineItem.fetchItem(itemId: nextItemId, includeSamples: true),
              !nextItem.deleted && !nextItem.disabled else {
            return
        }
        
        let timeGap = nextItem.timeInterval(from: item)
        
        // large gaps need visual distinction in the timeline view
        if timeGap > edgeHealingThreshold { 
            logger.info("Found data gap between \(item.debugShortId) and \(nextItem.debugShortId) (\(Int(timeGap))s)", subsystem: .timeline)
            
            try await createDataGapItem(between: item, and: nextItem)
        }
    }
    
    private static func checkDataGapWithPreviousItem(for item: TimelineItem) async throws {
        guard let prevItemId = item.base.previousItemId,
              !prevItemId.isEmpty,
              let prevItem = try await TimelineItem.fetchItem(itemId: prevItemId, includeSamples: true),
              !prevItem.deleted && !prevItem.disabled else { 
            return
        }
        
        let timeGap = item.timeInterval(from: prevItem)
        
        // large gaps need visual distinction in the timeline view
        if timeGap > edgeHealingThreshold {
            logger.info("Found data gap between \(prevItem.debugShortId) and \(item.debugShortId) (\(Int(timeGap))s)", subsystem: .timeline)
            
            try await createDataGapItem(between: prevItem, and: item)
        }
    }
}
