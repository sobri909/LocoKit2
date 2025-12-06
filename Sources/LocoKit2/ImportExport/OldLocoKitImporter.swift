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
    private static var wasObserving: Bool = true
    private static var wasRecording: Bool = false
    
    // MARK: - Public interface
    
    public static func startImport(dateRange: DateInterval? = nil) async throws {
        guard !importInProgress else {
            throw ImportExportError.importAlreadyInProgress
        }
        
        let startTime = Date()
        importInProgress = true
        currentPhase = .connecting
        progress = 0
        importDateRange = dateRange

        // save initial states and disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()
        
        // Track counts for summary
        var placesCount = 0
        var itemsCount = 0
        var samplesCount = 0
        var orphansProcessed = 0
        
        do {
            // Log import details
            if let dateRange = importDateRange {
                logger.info("Starting import with date range: \(dateRange.start) to \(dateRange.end)", subsystem: .importing)
            } else {
                logger.info("Starting import with no date restrictions", subsystem: .importing)
            }
            
            // Connect to databases
            try connectToDatabases()
            
            // Import Places (from ArcApp.sqlite)
            currentPhase = .importingPlaces
            placesCount = try await importPlaces()
            
            // Import Timeline Items (from LocoKit.sqlite)
            currentPhase = .importingTimelineItems
            let (importedCount, importedItemIds, itemDisabledStates) = try await importTimelineItems()
            itemsCount = importedCount
            
            // Import Samples (from LocoKit.sqlite)
            currentPhase = .importingSamples
            let (samples, orphans) = try await importSamples(importedItemIds: importedItemIds, itemDisabledStates: itemDisabledStates)
            samplesCount = samples
            orphansProcessed = orphans
            
            // Log summary
            let duration = Date().timeIntervalSince(startTime)
            let durationString = String(format: "%.1f", duration / 60.0) // minutes
            var summary = "OldLocoKitImporter completed successfully in \(durationString) minutes: "
            summary += "\(placesCount) places, \(itemsCount) items, \(samplesCount) samples"
            if orphansProcessed > 0 {
                summary += " (processed \(orphansProcessed) orphaned samples)"
            }
            logger.info(summary, subsystem: .importing)
            
            cleanupAndReset()
            
        } catch {
            logger.error("Database import failed: \(error)", subsystem: .importing)
            cleanupAndReset()
            throw error
        }
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
    
    // MARK: - Places Importing
    
    private static func importPlaces() async throws -> Int {
        logger.info("Starting Places import", subsystem: .importing)
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
        
        print("Read \(legacyPlaces.count) places from ArcApp database")
        
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
        logger.info("Places import completed", subsystem: .importing)
        return legacyPlaces.count
    }
    
    // MARK: - Timeline Items Importing

    private static func importTimelineItems() async throws -> (count: Int, itemIds: Set<String>, disabledStates: [String: Bool]) {
        logger.info("Starting Timeline Items import", subsystem: .importing)
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
            var query = LegacyItem.filter { $0.deleted == false }

            if let dateRange = importDateRange {
                query = query.filter { $0.startDate >= dateRange.start && $0.startDate < dateRange.end }
            }
            
            return try query.fetchAll(db)
        }
        
        print("Read \(legacyItems.count) timeline items from LocoKit database")
        
        let totalCount = legacyItems.count
        
        // Collect all item IDs that we'll be importing
        importedItemIds = Set(legacyItems.map { $0.itemId })
        
        // Import items in batches
        let batchSize = 200 // Smaller than places since items are more complex
        let batches = legacyItems.chunked(into: batchSize)

        // Build disabled states mapping as we import
        var itemDisabledStates: [String: Bool] = [:]

        for (batchIndex, batch) in batches.enumerated() {
            let batchDisabledStates = try await Database.pool.write { db -> [String: Bool] in
                var localStates: [String: Bool] = [:]

                for legacyItem in batch {
                    // Store edge relationships for later restoration
                    var previousId = legacyItem.previousItemId
                    var nextId = legacyItem.nextItemId
                    
                    // Sanitise circular edge references
                    if let prev = previousId, let next = nextId, prev == next {
                        logger.info("Item \(legacyItem.itemId) has circular edge reference: previousItemId == nextItemId", subsystem: .importing)
                        // Can't trust either edge - nil them both
                        previousId = nil
                        nextId = nil
                    }
                    
                    let record = EdgeRecordManager.EdgeRecord(
                        itemId: legacyItem.itemId,
                        previousId: previousId,
                        nextId: nextId
                    )
                    try edgeManager.saveRecord(record)
                    
                    // Create sanitised legacy item without edges for the init
                    var sanitisedLegacyItem = legacyItem
                    sanitisedLegacyItem.previousItemId = nil
                    sanitisedLegacyItem.nextItemId = nil
                    
                    // Create and save TimelineItem from legacy item
                    let item = try TimelineItem(from: sanitisedLegacyItem)
                    try item.base.insert(db, onConflict: .ignore)

                    // Track disabled state for sample import
                    localStates[item.id] = item.base.disabled
                    
                    // Save visit or trip component
                    if let visit = item.visit {
                        // check if placeId exists before saving
                        if let placeId = visit.placeId {
                            let placeExists = try Place.filter { $0.id == placeId }.fetchCount(db) > 0
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

                return localStates
            }

            // Merge batch disabled states into main collection
            itemDisabledStates.merge(batchDisabledStates) { (_, new) in new }
            
            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage / 2 // First half of the process
            
            // Progress logging for debugging
            if batchIndex % 20 == 0 || batchIndex == batches.count - 1 {
                print("Imported timeline items batch \(batchIndex + 1)/\(batches.count)")
            }
        }
        
        // Restore edge relationships
        print("Restoring timeline item edge relationships")
        try await edgeManager.restoreEdgeRelationships { progressPercentage in
            // Update progress (second half of process)
            progress = 0.5 + (progressPercentage / 2)
        }
        
        // Cleanup
        edgeManager.cleanup()
        
        progress = 1.0
        logger.info("Timeline Items import completed", subsystem: .importing)

        return (totalCount, importedItemIds, itemDisabledStates)
    }
    
    // MARK: - Sample Importing

    private static func importSamples(importedItemIds: Set<String>, itemDisabledStates: [String: Bool]) async throws -> (samples: Int, orphansProcessed: Int) {
        logger.info("Starting Samples import", subsystem: .importing)
        progress = 0
        
        guard let legacyPool = Database.legacyPool else {
            throw ImportExportError.missingLocoKitDatabase
        }
        
        // Track orphaned samples by their original parent timeline item ID
        var orphanedSamples: [String: [LocomotionSample]] = [:]

        // Track disabled samples from enabled parents (scenario 2) for preserved parent creation
        var disabledSamplesFromEnabledParents: [String: [LocomotionSample]] = [:]
        
        // Check if table exists and get sample count
        let (minRowId, maxRowId, totalCount) = try await legacyPool.read { [importDateRange] db in
            // Check if the LocomotionSample table exists
            let tableExists = try db.tableExists("LocomotionSample")
            guard tableExists else {
                throw ImportExportError.invalidDatabaseSchema
            }
            
            // Build base query with date filtering if needed
            var baseQuery = LegacySample.filter { $0.deleted == false }

            if let dateRange = importDateRange {
                baseQuery = baseQuery.filter { $0.date >= dateRange.start && $0.date < dateRange.end }
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
        
        print("Found \(totalCount) non-deleted samples (rowid range: \(minRowId)-\(maxRowId))")
        
        let batchSize = 1000
        var currentRowId = minRowId
        var processedCount = 0
        
        // Process in rowid-range batches
        while currentRowId <= maxRowId {
            let batchEndRowId = min(currentRowId + batchSize - 1, maxRowId)
            
            // Only read a chunk of samples in each iteration
            let batch = try await legacyPool.read { [currentRowId, batchEndRowId, importDateRange] db in
                var query = LegacySample
                    .filter { $0.deleted == false }
                    .filter(Column("rowid") >= currentRowId && Column("rowid") <= batchEndRowId)

                if let dateRange = importDateRange {
                    query = query.filter { $0.date >= dateRange.start && $0.date < dateRange.end }
                }

                return try query.order(Column("rowid")).fetchAll(db)
            }
            
            if !batch.isEmpty {
                try await processLegacySampleBatch(
                    batch,
                    importedItemIds: importedItemIds,
                    itemDisabledStates: itemDisabledStates,
                    orphanedSamples: &orphanedSamples,
                    disabledSamplesFromEnabledParents: &disabledSamplesFromEnabledParents
                )
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
        
        // Create preserved parent items for scenario 2 mismatches
        if !disabledSamplesFromEnabledParents.isEmpty {
            try await ImportHelpers.createPreservedParentItems(for: disabledSamplesFromEnabledParents)
        }

        // Process orphaned samples
        var orphansProcessed = 0
        if !orphanedSamples.isEmpty {
            let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
            logger.info("Found \(orphanedSamples.count) orphaned timeline items with \(totalOrphans) total orphaned samples", subsystem: .importing)
            
            // Log some details about the orphans
            print("OldLocoKitImporter orphan summary:")
            print("- Total orphaned items: \(orphanedSamples.count)")
            print("- Total orphaned samples: \(totalOrphans)")
            let sampleCounts = orphanedSamples.mapValues { $0.count }.sorted { $0.value > $1.value }
            print("- Top 10 items by sample count:")
            for (itemId, count) in sampleCounts.prefix(10) {
                print("  - Item \(itemId): \(count) samples")
            }
            
            // Process orphaned samples after main import
            let (recreated, individual) = try await OrphanedSampleProcessor.processOrphanedSamples(orphanedSamples)
            logger.info("OldLocoKitImporter orphan processing complete: \(recreated) items recreated, \(individual) individual items", subsystem: .importing)
            orphansProcessed = totalOrphans
        }
        
        progress = 1.0
        logger.info("Samples import completed: processed \(processedCount) samples", subsystem: .importing)
        
        return (processedCount, orphansProcessed)
    }
    
    // MARK: - Sample Processing Helpers
    
    // Process a batch of legacy samples
    private static func processLegacySampleBatch(
        _ batch: [LegacySample],
        importedItemIds: Set<String>,
        itemDisabledStates: [String: Bool],
        orphanedSamples: inout [String: [LocomotionSample]],
        disabledSamplesFromEnabledParents: inout [String: [LocomotionSample]]
    ) async throws {
        // Skip empty batches
        if batch.isEmpty { return }
        
        // Get all timeline item IDs referenced in this batch
        let itemIds = Set(batch.compactMap(\.timelineItemId))
        if itemIds.isEmpty {
            print("Skipping batch with no timeline item references")
            return
        }
        
        // Process the batch and collect orphans / mismatches
        let (batchOrphans, batchScenario2, orphanCount, scenario1Count, scenario2Count) = try await Database.pool.write { db in
            var localOrphans: [String: [LocomotionSample]] = [:]
            var localScenario2: [String: [LocomotionSample]] = [:]
            var localOrphanCount = 0
            var localScenario1Count = 0
            var localScenario2Count = 0

            for legacySample in batch {
                // Create new LocomotionSample from legacy data
                var sample = LocomotionSample(from: legacySample)

                // Check for disabled state mismatches
                if let itemId = sample.timelineItemId, let itemDisabled = itemDisabledStates[itemId] {
                    if itemDisabled && !sample.disabled {
                        // scenario 1: item disabled, sample enabled → force sample to disabled
                        sample.disabled = true
                        localScenario1Count += 1

                    } else if !itemDisabled && sample.disabled {
                        // scenario 2: item enabled, sample disabled → collect for preserved parent creation
                        localScenario2[itemId, default: []].append(sample)
                        localScenario2Count += 1
                        // orphan from current parent (will be reassigned to preserved parent later)
                        sample.timelineItemId = nil
                    }
                }

                // Check for references to missing TimelineItems
                if let originalItemId = legacySample.timelineItemId, !importedItemIds.contains(originalItemId) {
                    // Only treat as orphan if not disabled
                    if !legacySample.disabled {
                        localOrphans[originalItemId, default: []].append(sample)
                        localOrphanCount += 1
                    }
                    sample.timelineItemId = nil
                }
                
                // Insert the new sample with conflict handling for race conditions
                try sample.insert(db, onConflict: .ignore)
            }

            return (localOrphans, localScenario2, localOrphanCount, localScenario1Count, localScenario2Count)
        }
        
        // Log orphans if found
        if orphanCount > 0 {
            print("Found \(orphanCount) orphaned samples in current batch")
        }

        // Log disabled state mismatches
        if scenario1Count > 0 {
            logger.info("Normalized \(scenario1Count) samples (scenario 1: item.disabled=true, sample.disabled=false)", subsystem: .importing)
        }
        if scenario2Count > 0 {
            logger.info("Collected \(scenario2Count) samples for preserved parent creation (scenario 2: item.disabled=false, sample.disabled=true)", subsystem: .importing)
        }

        if !batchOrphans.isEmpty {
            for (itemId, samples) in batchOrphans {
                orphanedSamples[itemId, default: []].append(contentsOf: samples)
            }
        }

        if !batchScenario2.isEmpty {
            for (itemId, samples) in batchScenario2 {
                disabledSamplesFromEnabledParents[itemId, default: []].append(contentsOf: samples)
            }
        }
    }

    private static func cleanupAndReset() {
        // restore observation/recording to initial states
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            Task { try? await TimelineRecorder.startRecording() }
        }

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
        
        public var description: String {
            switch self {
            case .connecting: return "Connecting to databases"
            case .importingPlaces: return "Importing places"
            case .importingTimelineItems: return "Importing timeline items"
            case .importingSamples: return "Importing locomotion samples"
            }
        }
    }
    
}
