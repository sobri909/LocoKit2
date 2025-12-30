//
//  OrphanedSampleProcessor.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 29/5/25.
//

import Foundation
import GRDB

/// Shared processor for handling orphaned samples during import operations.
/// Used by both ImportManager and OldLocoKitImporter to avoid code duplication.
@ImportExportActor
public enum OrphanedSampleProcessor {
    
    /// Process orphaned samples by recreating timeline items or creating individual items.
    /// - Parameter orphanedSamples: Dictionary mapping original parent item IDs to arrays of orphaned samples
    /// - Returns: Tuple containing counts of (recreatedItems, individualItems)
    public static func processOrphanedSamples(_ orphanedSamples: [String: [LocomotionSample]]) async throws -> (recreated: Int, individual: Int) {
        var recreatedItems = 0
        var individualItems = 0
        
        let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
        Log.info("Starting orphan processing: \(orphanedSamples.count) groups, \(totalOrphans) total samples", subsystem: .database)
        
        // process each group of samples that belonged to the same original item
        for (originalItemId, samples) in orphanedSamples {
            // not enough samples to create a valid item
            if samples.count < TimelineItemTrip.minimumValidSamples {
                Log.info("Group \(originalItemId): \(samples.count) samples (below threshold) → creating individual items", subsystem: .database)
                try await createIndividualItems(for: samples)
                individualItems += samples.count
                continue
            }
            
            // analyze moving states to determine item type
            let stationarySamples = samples.filter { $0.movingState == .stationary }
            let stationaryRatio = Double(stationarySamples.count) / Double(samples.count)
            let stationaryPercentage = Int(stationaryRatio * 100)
            
            // high confidence for Visit (>80% stationary)
            if stationaryRatio > 0.8 {
                Log.info("Group \(originalItemId): \(samples.count) samples (\(stationaryPercentage)% stationary) → recreating as Visit", subsystem: .database)
                try await Database.pool.write { db in
                    _ = try TimelineItem.createItem(from: samples, isVisit: true, db: db)
                }
                recreatedItems += 1
                
            // high confidence for Trip (<20% stationary)
            } else if stationaryRatio < 0.2 {
                Log.info("Group \(originalItemId): \(samples.count) samples (\(stationaryPercentage)% stationary) → recreating as Trip", subsystem: .database)
                try await Database.pool.write { db in
                    _ = try TimelineItem.createItem(from: samples, isVisit: false, db: db)
                }
                recreatedItems += 1
                
            // mixed moving states, create individual items
            } else {
                Log.info("Group \(originalItemId): \(samples.count) samples (\(stationaryPercentage)% stationary, mixed) → creating individual items", subsystem: .database)
                try await createIndividualItems(for: samples)
                individualItems += samples.count
            }
        }
        
        Log.info("Processed orphaned samples: created \(recreatedItems) items and \(individualItems) individual samples", subsystem: .database)
        return (recreatedItems, individualItems)
    }
    
    /// Create individual timeline items for each sample based on its moving state
    private static func createIndividualItems(for samples: [LocomotionSample]) async throws {
        let visitCount = samples.filter { $0.movingState == .stationary }.count
        let tripCount = samples.count - visitCount
        Log.info("Creating \(samples.count) individual items: \(visitCount) visits, \(tripCount) trips", subsystem: .database)
        
        // create one item per sample based on its moving state
        for sample in samples {
            let isVisit = sample.movingState == .stationary
            
            try await Database.pool.write { db in
                _ = try TimelineItem.createItem(from: [sample], isVisit: isVisit, db: db)
            }
        }
    }
}