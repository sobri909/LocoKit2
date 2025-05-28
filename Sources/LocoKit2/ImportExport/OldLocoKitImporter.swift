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
    
    public private(set) static var importInProgress = false
    public private(set) static var currentPhase: ImportPhase?
    public private(set) static var progress: Double = 0

    // MARK: - Database connections
    
    private static var arcAppDatabase: DatabasePool?
    private static var importDateRange: DateInterval?
    
    // MARK: - Public interface
    
    public static func startImport(dateRange: DateInterval? = nil) async throws {
        guard !importInProgress else {
            throw ImportExportError.importAlreadyInProgress
        }
        
        importInProgress = true
        currentPhase = .connecting
        progress = 0
        importDateRange = dateRange
        
        do {
            // Log import details
            if let dateRange = importDateRange {
                logger.info("Starting import with date range: \(dateRange.start) to \(dateRange.end)", subsystem: .database)
            } else {
                logger.info("Starting import with no date restrictions", subsystem: .database)
            }
            
            // Connect to databases
            try connectToDatabases()
            
            // Import Places (from ArcApp.sqlite)
            currentPhase = .importingPlaces
            try await importPlaces()
            
            // Import Timeline Items (from LocoKit.sqlite)
            currentPhase = .importingTimelineItems
            let importedItemIds = try await importTimelineItems()
            
            // Import Samples (from LocoKit.sqlite)
            currentPhase = .importingSamples
            try await importSamples(importedItemIds: importedItemIds)
            
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
            throw ImportExportError.missingLocoKitDatabase
        }
        
        // Connect to ArcApp database
        guard let appGroupDir = Database.highlander.appGroupDbDir else {
            throw ImportExportError.databaseConnectionFailed
        }
        
        let arcAppUrl = appGroupDir.appendingPathComponent("ArcApp.sqlite")
        guard FileManager.default.fileExists(atPath: arcAppUrl.path) else {
            throw ImportExportError.missingArcAppDatabase
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
            throw ImportExportError.missingArcAppDatabase
        }
        
        // Read places from ArcApp.sqlite
        let legacyPlaces = try await arcAppDatabase.read { db in
            // Check if the Place table exists
            let tableExists = try db.tableExists("Place")
            guard tableExists else {
                throw ImportExportError.invalidDatabaseSchema
            }
            
            // Query all places
            return try LegacyPlace.fetchAll(db)
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
                    try place.insert(db, onConflict: .ignore)
                }
            }
            
            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage
            
            // Progress logging for debugging
            if batchIndex % 10 == 0 || batchIndex == batches.count - 1 {
                print("Imported places batch \(batchIndex + 1)/\(batches.count)")
            }
        }
        
        progress = 1.0
        logger.info("Places import completed", subsystem: .database)
    }
    
    private static func importTimelineItems() async throws -> Set<String> {
        logger.info("Starting Timeline Items import", subsystem: .database)
        progress = 0
        
        guard let legacyPool = Database.legacyPool else {
            throw ImportExportError.missingLocoKitDatabase
        }
        
        // Set up edge relationship manager
        let edgeManager = EdgeRecordManager()
        
        // Track imported item IDs for samples phase
        var importedItemIds = Set<String>()
        
        // Read timeline items from LocoKit.sqlite
        let legacyItems = try await legacyPool.read { [importDateRange] db in
            // Check if the TimelineItem table exists
            let tableExists = try db.tableExists("TimelineItem")
            guard tableExists else {
                throw ImportExportError.invalidDatabaseSchema
            }
            
            // Build query with date filtering if needed
            var query = LegacyItem.filter(Column("deleted") == false)
            
            if let dateRange = importDateRange {
                query = query.filter(Column("startDate") >= dateRange.start && Column("startDate") < dateRange.end)
            }
            
            return try query.fetchAll(db)
        }
        
        logger.info("Read \(legacyItems.count) timeline items from LocoKit database", subsystem: .database)
        
        // Collect all item IDs that we'll be importing
        importedItemIds = Set(legacyItems.map { $0.itemId })
        
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
                    try base.insert(db, onConflict: .ignore)
                    
                    
                    // Save visit or trip component
                    if let visit = item.visit {
                        // check if placeId exists before saving
                        if let placeId = visit.placeId {
                            let placeExists = try Place.filter(Column("id") == placeId).fetchCount(db) > 0
                            if !placeExists {
                                logger.warning("Visit \(visit.itemId) references non-existent place: \(placeId)")
                                // clear the invalid placeId
                                var mutableVisit = visit
                                mutableVisit.placeId = nil
                                mutableVisit.setUncertainty(true)
                                try mutableVisit.insert(db, onConflict: .ignore)
                            } else {
                                try visit.insert(db, onConflict: .ignore)
                            }
                        } else {
                            try visit.insert(db, onConflict: .ignore)
                        }
                    }
                    try item.trip?.insert(db, onConflict: .ignore)
                }
            }
            
            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage / 2 // First half of the process
            
            // Progress logging for debugging
            if batchIndex % 20 == 0 || batchIndex == batches.count - 1 {
                print("Imported timeline items batch \(batchIndex + 1)/\(batches.count)")
            }
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
        
        return importedItemIds
    }
    
    private static func importSamples(importedItemIds: Set<String>) async throws {
        logger.info("Starting Samples import", subsystem: .database)
        progress = 0
        
        guard let legacyPool = Database.legacyPool else {
            throw ImportExportError.missingLocoKitDatabase
        }
        
        // Track orphaned samples by their original parent timeline item ID
        var orphanedSamples: [String: [LocomotionSample]] = [:]
        
        // Check if table exists and get sample count
        let (minRowId, maxRowId, totalCount) = try await legacyPool.read { [importDateRange] db in
            // Check if the LocomotionSample table exists
            let tableExists = try db.tableExists("LocomotionSample")
            guard tableExists else {
                throw ImportExportError.invalidDatabaseSchema
            }
            
            // Build base query with date filtering if needed
            var baseQuery = LegacySample.filter(Column("deleted") == false)
            
            if let dateRange = importDateRange {
                baseQuery = baseQuery.filter(Column("date") >= dateRange.start && Column("date") < dateRange.end)
            }
            
            // Get min/max rowids and count for filtered samples
            let minRowId = try Int.fetchOne(db, 
                baseQuery.select(min(Column("rowid")))
            ) ?? 0
            
            let maxRowId = try Int.fetchOne(db, 
                baseQuery.select(max(Column("rowid")))
            ) ?? 0
            
            let count = try baseQuery.fetchCount(db)
            
            return (minRowId, maxRowId, count)
        }
        
        logger.info("Found \(totalCount) non-deleted samples (rowid range: \(minRowId)-\(maxRowId))", subsystem: .database)
        
        let batchSize = 1000
        var currentRowId = minRowId
        var processedCount = 0
        
        // Process in rowid-range batches
        while currentRowId <= maxRowId {
            let batchEndRowId = min(currentRowId + batchSize - 1, maxRowId)
            
            // Only read a chunk of samples in each iteration
            let batch = try await legacyPool.read { [currentRowId, batchEndRowId, importDateRange] db in
                var query = LegacySample
                    .filter(Column("deleted") == false)
                    .filter(Column("rowid") >= currentRowId && Column("rowid") <= batchEndRowId)
                
                if let dateRange = importDateRange {
                    query = query.filter(Column("date") >= dateRange.start && Column("date") < dateRange.end)
                }
                
                return try query.order(Column("rowid")).fetchAll(db)
            }
            
            if !batch.isEmpty {
                try await processLegacySampleBatch(batch, importedItemIds: importedItemIds, orphanedSamples: &orphanedSamples)
                processedCount += batch.count
                
                // Progress logging every 100 batches (100k samples)
                if (currentRowId / batchSize) % 100 == 0 {
                    print("Processed \(processedCount) samples...")
                }
            }
            
            // Update progress based on rowid position
            progress = Double(currentRowId - minRowId) / Double(maxRowId - minRowId)
            
            // Move to next batch
            currentRowId = batchEndRowId + 1
        }
        
        // Process orphaned samples
        if !orphanedSamples.isEmpty {
            let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
            logger.info("Found \(orphanedSamples.count) orphaned timeline items with \(totalOrphans) total orphaned samples", subsystem: .database)
            
            // Log some details about the orphans
            print("Orphaned samples summary:")
            print("- Total orphaned items: \(orphanedSamples.count)")
            print("- Total orphaned samples: \(totalOrphans)")
            let sampleCounts = orphanedSamples.mapValues { $0.count }.sorted { $0.value > $1.value }
            print("- Top 10 items by sample count:")
            for (itemId, count) in sampleCounts.prefix(10) {
                print("  - Item \(itemId): \(count) samples")
            }
            
            // TODO: Enable orphan processing once main import is stable
            // try await processOrphanedSamples(orphanedSamples)
        }
        
        progress = 1.0
        logger.info("Samples import completed: processed \(processedCount) samples", subsystem: .database)
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
                /*
                try await Database.pool.write { db in
                    // Create a visit using the proper method (also handles sample references)
                    let _ = try TimelineItem.createItem(from: samples, isVisit: true, db: db)
                }
                */
                recreatedItems += 1
                logger.info("Recreated Visit for lost item \(originalItemId) with \(samples.count) samples", subsystem: .database)
                
            // High confidence for Trip (<20% stationary)
            } else if stationaryRatio < 0.2 {
                /*
                try await Database.pool.write { db in
                    // Create a trip using the proper method (also handles sample references)
                    let _ = try TimelineItem.createItem(from: samples, isVisit: false, db: db)
                }
                */
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
        for _ in samples {
            /*
            try await Database.pool.write { db in
                // Create a new item using the proper method (also handles sample references)
                let _ = try TimelineItem.createItem(from: [sample], isVisit: isVisit, db: db)
            }
             */
        }
    }
    
    // MARK: - Sample Processing Helpers
    
    // Process a batch of legacy samples
    private static func processLegacySampleBatch(_ batch: [LegacySample], importedItemIds: Set<String>, orphanedSamples: inout [String: [LocomotionSample]]) async throws {
        // Skip empty batches
        if batch.isEmpty { return }
        
        // Get all timeline item IDs referenced in this batch
        let itemIds = Set(batch.compactMap(\.timelineItemId))
        if itemIds.isEmpty {
            logger.info("Skipping batch with no timeline item references", subsystem: .database)
            return
        }
        
        // Process the batch and collect orphans
        let (batchOrphans, orphanCount) = try await Database.pool.write { db in
            var localOrphans: [String: [LocomotionSample]] = [:]
            var localOrphanCount = 0
            
            for legacySample in batch {
                // Create new LocomotionSample from legacy data
                var sample = LocomotionSample(from: legacySample)
                
                // Check for references to missing TimelineItems
                if let originalItemId = sample.timelineItemId, !importedItemIds.contains(originalItemId) {
                    // Only treat as orphan if not disabled
                    if !legacySample.disabled {
                        localOrphans[originalItemId, default: []].append(sample)
                        localOrphanCount += 1
                    }
                    sample.timelineItemId = nil
                }
                
                // Insert the new sample (instead of save) as this is a new record
                try sample.insert(db)
            }
            
            return (localOrphans, localOrphanCount)
        }
        
        // Log orphans if found (won't happen in simulation mode)
        if orphanCount > 0 {
            print("Found \(orphanCount) orphaned samples")
        }
        
        if !batchOrphans.isEmpty {
            for (itemId, samples) in batchOrphans {
                orphanedSamples[itemId, default: []].append(contentsOf: samples)
            }
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
        importDateRange = nil
    }

    // MARK: - Supporting types

    public enum ImportPhase: Sendable {
        case connecting
        case importingPlaces
        case importingTimelineItems
        case importingSamples
        case importingNotes
        case validatingData
        
        public var description: String {
            switch self {
            case .connecting: return "Connecting to databases"
            case .importingPlaces: return "Importing places"
            case .importingTimelineItems: return "Importing timeline items"
            case .importingSamples: return "Importing locomotion samples"
            case .importingNotes: return "Importing notes"
            case .validatingData: return "Validating imported data"
            }
        }
    }
    
}
