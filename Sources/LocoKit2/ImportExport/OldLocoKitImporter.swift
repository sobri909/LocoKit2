//
//  OldLocoKitImporter.swift
//  LocoKit2
//
//  Created on 2025-05-20
//

import Foundation
import GRDB

@ImportExportActor
public enum OldLocoKitImporter {
    
    // MARK: - Import state
    
    private(set) static var importInProgress = false
    private(set) static var currentPhase: ImportPhase?
    private(set) static var progress: Double = 0
    
    // MARK: - Database connections
    
    private static var arcAppDatabase: DatabasePool?
    
    // MARK: - Public interface
    
    public static func startImport() async throws {
        guard !importInProgress else {
            throw ImportError.importAlreadyInProgress
        }
        
        importInProgress = true
        currentPhase = .connecting
        progress = 0
        
        do {
            // Connect to databases
            try connectToDatabases()
            
            // Import Places (from ArcApp.sqlite)
            currentPhase = .importingPlaces
            try await importPlaces()
            
            // Import Timeline Items (from LocoKit.sqlite)
            currentPhase = .importingTimelineItems
            try await importTimelineItems()
            
            // Import Samples (from LocoKit.sqlite)
            currentPhase = .importingSamples
            try await importSamples()
            
            // Import Notes (from ArcApp.sqlite)
            currentPhase = .importingNotes
            try await importNotes()
            
            // Validate imported data
            currentPhase = .validatingData
            try await validateImportedData()
            
            logger.info("Database import completed successfully", subsystem: .database)
            cleanupAndReset()
            
        } catch {
            logger.error("Database import failed: \(error)", subsystem: .database)
            cleanupAndReset()
            throw error
        }
    }
    
    public static func cancelImport() {
        guard importInProgress else { return }
        cleanupAndReset()
    }
    
    // MARK: - Private helpers
    
    private static func connectToDatabases() throws {
        // Check for legacy LocoKit database
        guard Database.legacyPool != nil else {
            throw ImportError.missingLocoKitDatabase
        }
        
        // Connect to ArcApp database
        guard let appGroupDir = Database.highlander.appGroupDbDir else {
            throw ImportError.databaseConnectionFailed
        }
        
        let arcAppUrl = appGroupDir.appendingPathComponent("ArcApp.sqlite")
        guard FileManager.default.fileExists(atPath: arcAppUrl.path) else {
            throw ImportError.missingArcAppDatabase
        }
        
        // Configure read-only connection to ArcApp database
        var config = Configuration()
        config.readonly = true
        
        arcAppDatabase = try DatabasePool(path: arcAppUrl.path, configuration: config)
    }
    
    private static func importPlaces() async throws {
        logger.info("Starting Places import", subsystem: .database)
        progress = 0
        
        guard let arcAppDatabase else {
            throw ImportError.missingArcAppDatabase
        }
        
        // Read places from ArcApp.sqlite
        let legacyPlaces = try await arcAppDatabase.read { db in
            // Check if the Place table exists
            let tableExists = try db.tableExists("Place")
            guard tableExists else {
                throw ImportError.invalidDatabaseSchema
            }
            
            // Query all places that aren't deleted
            return try LegacyPlace.filter(sql: "deleted = 0").fetchAll(db)
        }
        
        logger.info("Read \(legacyPlaces.count) places from ArcApp database", subsystem: .database)
        
        // Import places in batches
        let batchSize = 500
        let batches = legacyPlaces.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try await Database.pool.write { db in
                for legacyPlace in batch {
                    // Convert legacy place to new Place model
                    let place = Place(from: legacyPlace)
                    
                    // Save the place (RTree will be created automatically via trigger)
                    try place.save(db)
                }
            }
            
            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage
            
            logger.info("Imported places batch \(batchIndex + 1)/\(batches.count)", subsystem: .database)
        }
        
        progress = 1.0
        logger.info("Places import completed", subsystem: .database)
    }
    
    private static func importTimelineItems() async throws {
        logger.info("Starting Timeline Items import", subsystem: .database)
        progress = 0
        
        guard let legacyPool = Database.legacyPool else {
            throw ImportError.missingLocoKitDatabase
        }
        
        // Set up edge relationship manager
        let edgeManager = EdgeRecordManager()
        
        // Read timeline items from LocoKit.sqlite
        let legacyItems = try await legacyPool.read { db in
            // Check if the TimelineItem table exists
            let tableExists = try db.tableExists("TimelineItem")
            guard tableExists else {
                throw ImportError.invalidDatabaseSchema
            }
            
            // Fetch only non-deleted items
            return try LegacyItem.filter(sql: "deleted = 0").fetchAll(db)
        }
        
        logger.info("Read \(legacyItems.count) timeline items from LocoKit database", subsystem: .database)
        
        // Import items in batches
        let batchSize = 200 // Smaller than places since items are more complex
        let batches = legacyItems.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try await Database.pool.write { db in
                for legacyItem in batch {
                    // Store edge relationships for later restoration
                    let record = EdgeRecordManager.EdgeRecord(
                        itemId: legacyItem.itemId,
                        previousId: legacyItem.previousItemId,
                        nextId: legacyItem.nextItemId
                    )
                    
                    // Save edge record
                    try edgeManager.saveRecord(record)
                    
                    // Create and save TimelineItem from legacy item
                    let item = try TimelineItem(from: legacyItem)
                    
                    // Clear edge relationships for initial import (will restore later)
                    var base = item.base
                    base.previousItemId = nil
                    base.nextItemId = nil
                    try base.save(db)
                    
                    // Save visit or trip component
                    try item.visit?.save(db)
                    try item.trip?.save(db)
                }
            }
            
            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage / 2 // First half of the process
            
            logger.info("Imported timeline items batch \(batchIndex + 1)/\(batches.count)", subsystem: .database)
        }
        
        // Restore edge relationships
        logger.info("Restoring timeline item edge relationships", subsystem: .database)
        try await edgeManager.restoreEdgeRelationships { progressPercentage in
            // Update progress (second half of process)
            progress = 0.5 + (progressPercentage / 2)
        }
        
        // Cleanup
        edgeManager.cleanup()
        
        progress = 1.0
        logger.info("Timeline Items import completed", subsystem: .database)
    }
    
    private static func importSamples() async throws {
        logger.info("Starting Samples import", subsystem: .database)
        progress = 0
        
        guard Database.legacyPool != nil else {
            throw ImportError.missingLocoKitDatabase
        }
        
        // First, get a count of samples to import for progress tracking
        let sampleCount = try await Database.legacyPool!.read { db in
            // Check if the LocomotionSample table exists
            let tableExists = try db.tableExists("LocomotionSample")
            guard tableExists else {
                throw ImportError.invalidDatabaseSchema
            }
            
            // Count non-deleted samples
            return try Int.fetchOne(db, 
                sql: "SELECT COUNT(*) FROM LocomotionSample WHERE deleted = 0"
            ) ?? 0
        }
        
        logger.info("Found \(sampleCount) samples to import from LocoKit database", subsystem: .database)
        
        // Define batch size for processing
        let batchSize = 1000
        
        // Track orphaned samples by their original parent timeline item ID
        var orphanedSamples: [String: [LocomotionSample]] = [:]
        
        // Process in cursor-based batches
        try await processSamplesInBatches(
            batchSize: batchSize,
            sampleCount: sampleCount,
            orphanedSamples: &orphanedSamples
        )
        
        // Process orphaned samples after all imports complete
        if !orphanedSamples.isEmpty {
            logger.info("Processing \(orphanedSamples.count) sets of orphaned samples", subsystem: .database)
            try await processOrphanedSamples(orphanedSamples)
        }
        
        progress = 1.0
        logger.info("Samples import completed", subsystem: .database)
    }
    
    private static func processOrphanedSamples(_ orphanedSamples: [String: [LocomotionSample]]) async throws {
        var recreatedItems = 0
        var individualItems = 0
        
        // Process each group of samples that belonged to the same original item
        for (originalItemId, samples) in orphanedSamples {
            // Not enough samples to create a valid item
            if samples.count < 5 { // Using a small threshold for valid item creation
                try await createIndividualItems(for: samples)
                individualItems += samples.count
                continue
            }
            
            // Analyze moving states to determine item type
            let stationarySamples = samples.filter { $0.movingState == .stationary }
            let stationaryRatio = Double(stationarySamples.count) / Double(samples.count)
            
            // High confidence for Visit (>80% stationary)
            if stationaryRatio > 0.8 {
                try await Database.pool.write { db in
                    // Create a visit using the proper method (also handles sample references)
                    let _ = try TimelineItem.createItem(from: samples, isVisit: true, db: db)
                }
                recreatedItems += 1
                logger.info("Recreated Visit for lost item \(originalItemId) with \(samples.count) samples", subsystem: .database)
                
            // High confidence for Trip (<20% stationary)
            } else if stationaryRatio < 0.2 {
                try await Database.pool.write { db in
                    // Create a trip using the proper method (also handles sample references)
                    let _ = try TimelineItem.createItem(from: samples, isVisit: false, db: db)
                }
                recreatedItems += 1
                logger.info("Recreated Trip for lost item \(originalItemId) with \(samples.count) samples", subsystem: .database)
                
            // Mixed moving states, create individual items
            } else {
                try await createIndividualItems(for: samples)
                individualItems += samples.count
                logger.info("Created \(samples.count) individual items for lost item \(originalItemId) (mixed states)", subsystem: .database)
            }
        }
        
        logger.info("Processed orphaned samples: created \(recreatedItems) items and \(individualItems) individual samples", subsystem: .database)
    }
    
    private static func createIndividualItems(for samples: [LocomotionSample]) async throws {
        // Create one item per sample based on its moving state
        for sample in samples {
            let isVisit = sample.movingState == .stationary
            
            try await Database.pool.write { db in
                // Create a new item using the proper method (also handles sample references)
                let _ = try TimelineItem.createItem(from: [sample], isVisit: isVisit, db: db)
            }
        }
    }
    
    // MARK: - Sample Processing Helpers
    
    // Helper method for processing samples in batches with cursor-based iteration
    private static func processSamplesInBatches(
        batchSize: Int,
        sampleCount: Int,
        orphanedSamples: inout [String: [LocomotionSample]]
    ) async throws {
        var processed = 0
        var allBatches: [[LegacySample]] = []
        
        // First, read all the samples in batches (synchronous operation)
        guard let legacyPool = Database.legacyPool else {
            throw ImportError.missingLocoKitDatabase
        }
        
        try await legacyPool.read { db in
            // Create a request for non-deleted samples with incremental primary key ordering
            let request = LegacySample
                .filter(sql: "deleted = 0")
                .order(Column("rowid"))
            
            // Use a cursor to stream results without loading all into memory
            let cursor = try request.fetchCursor(db)
            
            // Read in batches
            var currentBatch: [LegacySample] = []
            currentBatch.reserveCapacity(batchSize)
            
            // Process the cursor
            while let sample = try cursor.next() {
                currentBatch.append(sample)
                
                // When batch is full, save it
                if currentBatch.count >= batchSize {
                    allBatches.append(currentBatch)
                    currentBatch = []
                    currentBatch.reserveCapacity(batchSize)
                }
            }
            
            // Add any remaining samples in the last batch
            if !currentBatch.isEmpty {
                allBatches.append(currentBatch)
            }
        }
        
        // Now process all batches (async operation)
        for (batchIndex, batch) in allBatches.enumerated() {
            try await processSampleBatch(
                batch,
                batchCount: batchIndex + 1,
                orphanedSamples: &orphanedSamples
            )
            
            // Update progress
            processed += batch.count
            progress = Double(processed) / Double(sampleCount)
            
            logger.info("Processed batch \(batchIndex + 1)/\(allBatches.count) with \(batch.count) samples", subsystem: .database)
        }
    }
    
    // Process a batch of legacy samples
    private static func processSampleBatch(
        _ batch: [LegacySample],
        batchCount: Int,
        orphanedSamples: inout [String: [LocomotionSample]]
    ) async throws {
        logger.info("Processing sample batch #\(batchCount) with \(batch.count) samples", subsystem: .database)
        
        // Get all timeline item IDs referenced in this batch
        let itemIds = Set(batch.compactMap(\.timelineItemId))
        if itemIds.isEmpty { return }
        
        // Query the database for valid timeline item IDs
        let validIds = try await Database.pool.read { db in
            try String.fetchSet(db, TimelineItemBase
                .select(Column("id"))
                .filter(itemIds.contains(Column("id"))))
        }
        
        try await Database.pool.write { db in
            // Track orphaned samples by original timeline item ID
            var batchOrphans: [String: [LocomotionSample]] = [:]
            var orphanedCount = 0
            
            for legacySample in batch {
                // Skip disabled samples
                guard !legacySample.disabled else { continue }
                
                // Create new sample from legacy data
                var sample = LocomotionSample(from: legacySample)
                
                // Check for invalid references to missing TimelineItems
                if let originalItemId = sample.timelineItemId, !validIds.contains(originalItemId) {
                    batchOrphans[originalItemId, default: []].append(sample)
                    sample.timelineItemId = nil
                    orphanedCount += 1
                }
                
                // Save the sample (RTree will be created automatically via trigger)
                try sample.save(db)
            }
            
            if orphanedCount > 0 {
                logger.info("Found \(orphanedCount) orphaned samples with missing parent items", subsystem: .database)
            }
            
            // Return the batch orphans to be added to the main collection
            await updateOrphanedSamples(batchOrphans, in: &orphanedSamples)
        }
    }
    
    // Helper to update orphanedSamples in a way that avoids the concurrency issue
    @ImportExportActor
    private static func updateOrphanedSamples(_ batchOrphans: [String: [LocomotionSample]], in orphanedSamples: inout [String: [LocomotionSample]]) {
        for (itemId, samples) in batchOrphans {
            orphanedSamples[itemId, default: []].append(contentsOf: samples)
        }
    }
    
    private static func importNotes() async throws {
        logger.info("Starting Notes import", subsystem: .database)
        progress = 0
        
        // Implementation will be added in subsequent steps
        
        progress = 1.0
        logger.info("Notes import completed", subsystem: .database)
    }
    
    private static func validateImportedData() async throws {
        logger.info("Validating imported data", subsystem: .database)
        progress = 0
        
        // Implementation will be added in subsequent steps
        
        progress = 1.0
        logger.info("Data validation completed", subsystem: .database)
    }
    
    private static func cleanupAndReset() {
        arcAppDatabase = nil
        importInProgress = false
        currentPhase = nil
        progress = 0
    }

    // MARK: - Supporting types

    public enum ImportPhase {
        case connecting
        case importingPlaces
        case importingTimelineItems
        case importingSamples
        case importingNotes
        case validatingData
        
        var description: String {
            switch self {
            case .connecting: return "Connecting to databases"
            case .importingPlaces: return "Importing places"
            case .importingTimelineItems: return "Importing timeline items"
            case .importingSamples: return "Importing location samples"
            case .importingNotes: return "Importing notes"
            case .validatingData: return "Validating imported data"
            }
        }
    }
    
    public enum ImportError: Error {
        case importAlreadyInProgress
        case databaseConnectionFailed
        case missingLocoKitDatabase
        case missingArcAppDatabase
        case invalidDatabaseSchema
        case importCancelled
        case placeImportFailed
        case timelineItemImportFailed
        case sampleImportFailed
        case noteImportFailed
        case validationFailed
    }
    
}
