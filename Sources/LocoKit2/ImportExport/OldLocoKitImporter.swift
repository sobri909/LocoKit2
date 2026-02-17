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

    // MARK: - Data availability

    /// check if old Arc Timeline databases exist (for import availability detection)
    nonisolated
    public static var hasOldArcTimelineData: Bool {
        guard let appGroupDir = Database.highlander.appGroupDbDir else { return false }
        let locoKitExists = FileManager.default.fileExists(atPath: appGroupDir.appendingPathComponent("LocoKit.sqlite").path)
        let arcAppExists = FileManager.default.fileExists(atPath: appGroupDir.appendingPathComponent("ArcApp.sqlite").path)
        return locoKitExists && arcAppExists
    }

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
        
        do {
            if let dateRange = importDateRange {
                Log.info("Starting import with date range: \(dateRange.start) to \(dateRange.end)", subsystem: .importing)
            } else {
                Log.info("Starting import with no date restrictions", subsystem: .importing)
            }

            try connectToDatabases()

            // create import state for resume tracking
            let importState = OldLocoKitImportState(startedAt: startTime, phase: .places)
            try await OldLocoKitImportState.save(importState)

            try await performImportPhases(startTime: startTime, isResume: false)

        } catch {
            Log.error("Database import failed: \(error)", subsystem: .importing)
            // preserve import state for resume (do NOT clear)
            cleanupAndReset()
            throw error
        }
    }
    
    public static func resumeImport(dateRange: DateInterval? = nil) async throws {
        guard !importInProgress else {
            throw ImportExportError.importAlreadyInProgress
        }

        guard let state = try await OldLocoKitImportState.current() else {
            throw ImportExportError.importNotInitialised
        }

        let startTime = Date()
        importInProgress = true
        progress = 0
        importDateRange = dateRange

        // save initial states and disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()

        do {
            Log.info("Resuming old LocoKit import from phase: \(state.phase.rawValue)", subsystem: .importing)

            try connectToDatabases()

            try await performImportPhases(
                resumeFromRowId: state.lastProcessedSampleRowId,
                startTime: startTime,
                isResume: true
            )

        } catch {
            Log.error("OldLocoKitImporter resume failed: \(error)", subsystem: .importing)
            // preserve import state for next resume attempt
            cleanupAndReset()
            throw error
        }
    }

    // MARK: - Private helpers

    private static func performImportPhases(
        resumeFromRowId: Int? = nil,
        startTime: Date,
        isResume: Bool
    ) async throws {
        // Import Places (from ArcApp.sqlite)
        currentPhase = .importingPlaces
        let placesCount = try await importPlaces()
        try await OldLocoKitImportState.updatePhase(.items)

        // Import Timeline Items (from LocoKit.sqlite)
        currentPhase = .importingTimelineItems
        let (itemsCount, importedItemIds, itemDisabledStates) = try await importTimelineItems()
        try await OldLocoKitImportState.updatePhase(.samples)

        // Import Samples (from LocoKit.sqlite)
        currentPhase = .importingSamples
        let (samplesCount, orphansProcessed) = try await importSamples(
            importedItemIds: importedItemIds,
            itemDisabledStates: itemDisabledStates,
            resumeFromRowId: resumeFromRowId
        )

        // log summary
        let duration = Date().timeIntervalSince(startTime)
        let durationString = String(format: "%.1f", duration / 60.0)
        let prefix = isResume ? "OldLocoKitImporter (resumed) completed in" : "OldLocoKitImporter completed successfully in"
        var summary = "\(prefix) \(durationString) minutes: "
        summary += "\(placesCount) places, \(itemsCount) items, \(samplesCount) samples"
        if orphansProcessed > 0 {
            summary += " (processed \(orphansProcessed) orphaned samples)"
        }
        Log.info(summary, subsystem: .importing)

        // clear state on success
        try await OldLocoKitImportState.clear()

        cleanupAndReset()
    }

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
        Log.info("Starting Places import", subsystem: .importing)
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
        Log.info("Places import completed", subsystem: .importing)
        return legacyPlaces.count
    }
    
    // MARK: - Timeline Items Importing

    private static func importTimelineItems() async throws -> (count: Int, itemIds: Set<String>, disabledStates: [String: Bool]) {
        Log.info("Starting Timeline Items import", subsystem: .importing)
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
                        Log.info("Item \(legacyItem.itemId) has circular edge reference: previousItemId == nextItemId", subsystem: .importing)
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
                                Log.info("Visit \(visit.itemId) references non-existent place: \(placeId)", subsystem: .importing)
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
        Log.info("Timeline Items import completed", subsystem: .importing)

        return (totalCount, importedItemIds, itemDisabledStates)
    }
    
    // MARK: - Sample Importing

    private static func importSamples(importedItemIds: Set<String>, itemDisabledStates: [String: Bool], resumeFromRowId: Int? = nil) async throws -> (samples: Int, orphansProcessed: Int) {
        Log.info("Starting Samples import", subsystem: .importing)
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
        var currentRowId = resumeFromRowId.map { $0 + 1 } ?? minRowId
        var processedCount = 0
        var failedBatchCount = 0

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
                do {
                    try await processLegacySampleBatch(
                        batch,
                        importedItemIds: importedItemIds,
                        itemDisabledStates: itemDisabledStates,
                        orphanedSamples: &orphanedSamples,
                        disabledSamplesFromEnabledParents: &disabledSamplesFromEnabledParents
                    )
                    processedCount += batch.count
                    try await OldLocoKitImportState.updateLastProcessedSampleRowId(batchEndRowId)

                } catch {
                    failedBatchCount += 1
                    Log.error("Sample batch failed (rowids \(currentRowId)-\(batchEndRowId)): \(error)", subsystem: .importing)
                }

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

        if failedBatchCount > 0 {
            Log.error("Sample import completed with \(failedBatchCount) failed batches out of \(processedCount + failedBatchCount * batchSize) samples", subsystem: .importing)
        }
        
        // Create preserved parent items for scenario 2 mismatches
        if !disabledSamplesFromEnabledParents.isEmpty {
            try await ImportHelpers.createPreservedParentItems(for: disabledSamplesFromEnabledParents)
        }

        // Process orphaned samples
        var orphansProcessed = 0
        if !orphanedSamples.isEmpty {
            let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
            Log.info("Found \(orphanedSamples.count) orphaned timeline items with \(totalOrphans) total orphaned samples", subsystem: .importing)
            
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
            Log.info("OldLocoKitImporter orphan processing complete: \(recreated) items recreated, \(individual) individual items", subsystem: .importing)
            orphansProcessed = totalOrphans
        }
        
        progress = 1.0
        Log.info("Samples import completed: processed \(processedCount) samples", subsystem: .importing)
        
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
        if batch.isEmpty { return }

        // convert legacy samples to LocomotionSamples
        let samples = batch.map { LocomotionSample(from: $0) }

        let batchResult = try await Database.pool.write { db in
            try SampleImportProcessor.processBatch(
                samples: samples,
                validItemIds: importedItemIds,
                itemDisabledStates: itemDisabledStates,
                orphanOnlyIfEnabled: true,  // legacy import only orphans enabled samples
                db: db
            )
        }

        // log results (uses print for orphans in legacy import)
        if batchResult.orphanCount > 0 {
            print("Found \(batchResult.orphanCount) orphaned samples in current batch")
        }
        SampleImportProcessor.logBatchResults(batchResult)

        SampleImportProcessor.mergeResults(batchResult, into: &orphanedSamples, scenario2: &disabledSamplesFromEnabledParents)
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
