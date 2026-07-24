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

    /// BIG-621: the last completed import found no timeline data in the legacy source (the
    /// fresh-v3-on-new-phone shape). In-memory one-shot: drives the app's "no old data found"
    /// cover in-session; a relaunch lands in a clean no-migration state anyway (no state row,
    /// coverage gate false), so nothing needs to persist.
    public private(set) static var lastCompletionWasEmptySource = false

    /// BIG-621: user has seen the empty-source outcome — clear it so the cover stops showing.
    public static func acknowledgeEmptySourceCompletion() {
        lastCompletionWasEmptySource = false
    }

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

    // cached per launch: the legacy db only ever gains newer data
    private static var cachedLegacyEarliestItemDate: Date??

    /// earliest non-deleted item date in the legacy LocoKit database (BIG-629)
    public static func legacyEarliestItemDate() async -> Date? {
        if let cached = cachedLegacyEarliestItemDate { return cached }
        guard let legacyPool = Database.legacyPool else { return nil }
        let earliest = try? await legacyPool.read { db -> Date? in
            let request = LegacyItem
                .filter { $0.deleted == false }
                .select { min($0.startDate) }
            return try request.asRequest(of: Date.self).fetchOne(db)
        }
        cachedLegacyEarliestItemDate = .some(earliest ?? nil)
        return earliest ?? nil
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
        lastCompletionWasEmptySource = false

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

            // BIG-598: count this attempt, committed before the heavy work so an OOM/watchdog
            // kill is still counted next launch. Reset to 0 once samples progress is made.
            try await OldLocoKitImportState.recordAttemptStart()

            try await performImportPhases(startTime: startTime, isResume: false)

        } catch {
            Log.error("Database import failed: \(error)", subsystem: .importing)
            // preserve import state for resume (do NOT clear); capture the failure for the
            // BIG-598 give-up UI
            try? await OldLocoKitImportState.recordError(error)
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
        lastCompletionWasEmptySource = false

        // save initial states and disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()

        do {
            Log.info("Resuming old LocoKit import from phase: \(state.phase.rawValue)", subsystem: .importing)
            if let dateRange = importDateRange {
                Log.info("Resuming import with date range: \(dateRange.start) to \(dateRange.end)", subsystem: .importing)
            }

            // BIG-598: count this attempt before the heavy work, so an OOM/watchdog kill is still
            // counted next launch. Reset to 0 once samples progress is made.
            try await OldLocoKitImportState.recordAttemptStart()

            try connectToDatabases()

            try await performImportPhases(
                resumeFromRowId: state.lastProcessedSampleRowId,
                startTime: startTime,
                isResume: true
            )

        } catch {
            Log.error("OldLocoKitImporter resume failed: \(error)", subsystem: .importing)
            // preserve import state for next resume attempt; capture the failure for the
            // BIG-598 give-up UI
            try? await OldLocoKitImportState.recordError(error)
            cleanupAndReset()
            throw error
        }
    }

    // MARK: - Backfills

    /// One-shot backfill: copies `foursquareCategoryId` (Foursquare V2 string id) from
    /// `ArcApp.sqlite` onto already-imported `Place` rows whose `foursquareCategoryV2Id`
    /// is still NULL. Use this when an existing install has already run the legacy
    /// import on a build that didn't preserve the field.
    ///
    /// No-op when `hasOldArcTimelineData` is false. Idempotent — only updates rows
    /// where `Place.foursquareCategoryV2Id IS NULL`, matching on
    /// `Place.id == LegacyPlace.placeId` AND
    /// `Place.foursquarePlaceId == LegacyPlace.foursquareVenueId`.
    ///
    /// IMPORTANT: this library does not record whether the backfill has been run.
    /// The calling app is responsible for tracking completion (e.g. via UserDefaults)
    /// so it isn't re-run on every launch.
    ///
    /// - Returns: number of `Place` rows updated.
    @discardableResult
    public static func backfillFoursquareCategoryV2Id() async throws -> Int {
        guard !importInProgress else {
            throw ImportExportError.importAlreadyInProgress
        }
        guard hasOldArcTimelineData else { return 0 }
        guard let appGroupDir = Database.highlander.appGroupDbDir else {
            throw ImportExportError.databaseConnectionFailed
        }

        // claim the import slot so a concurrent startImport/resumeImport can't
        // race us across await suspension points
        importInProgress = true
        defer { importInProgress = false }

        let arcAppUrl = appGroupDir.appendingPathComponent("ArcApp.sqlite")

        var arcConfig = Configuration()
        arcConfig.readonly = true
        let arcPool = try DatabasePool(path: arcAppUrl.path, configuration: arcConfig)

        Log.info("Starting foursquareCategoryV2Id backfill", subsystem: .importing)
        let start = Date()

        let legacyPlaces = try await arcPool.read { db in
            guard try db.tableExists("Place"),
                  try db.columns(in: "Place").contains(where: { $0.name == "foursquareCategoryId" }) else {
                return [LegacyPlace]()
            }
            return try LegacyPlace
                .filter(LegacyPlace.Columns.foursquareCategoryId != nil)
                .filter(LegacyPlace.Columns.foursquareVenueId != nil)
                .fetchAll(db)
        }

        let batchSize = 500
        let batches = legacyPlaces.chunked(into: batchSize)
        var updateCount = 0

        for batch in batches {
            let batchUpdated = try await Database.pool.write { db -> Int in
                var localCount = 0
                for lp in batch {
                    guard let categoryId = lp.foursquareCategoryId,
                          let venueId = lp.foursquareVenueId else { continue }
                    try db.execute(sql: """
                        UPDATE Place
                        SET foursquareCategoryV2Id = ?
                        WHERE id = ?
                          AND foursquarePlaceId = ?
                          AND foursquareCategoryV2Id IS NULL
                        """, arguments: [categoryId, lp.placeId, venueId])
                    localCount += db.changesCount
                }
                return localCount
            }
            updateCount += batchUpdated
        }

        Log.info("foursquareCategoryV2Id backfill: updated \(updateCount) places (of \(legacyPlaces.count) candidates) in \(String(format: "%.1f", -start.timeIntervalSinceNow))s", subsystem: .importing)

        return updateCount
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

        // BIG-621: a source with zero timeline items is the fresh-v3-on-new-phone shape —
        // complete gracefully before the samples phase (whose orphan machinery has no business
        // running against a zero-item source) and flag the outcome for the app to present.
        // The in-window read count is only the trigger; the authoritative check is whole-source
        // emptiness (nil earliest non-deleted item), because the app always imports with the
        // BIG-629 dedup window (distantPast → earliestLocoKit2DataDate) — zero items in-window
        // against a NON-empty source (parallel-era-only data) must complete silently instead,
        // since "no old data found" would be false there.
        if itemsCount == 0, await legacyEarliestItemDate() == nil {
            Log.info("OldLocoKitImporter completed: no timeline data found in legacy source (\(placesCount) places)", subsystem: .importing)
            lastCompletionWasEmptySource = true
            try await OldLocoKitImportState.clear()
            cleanupAndReset()
            return
        }

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
        
        Log.info("Read \(legacyPlaces.count) places from ArcApp database", subsystem: .importing)
        
        // Import places in batches
        let batchSize = 500
        let batches = legacyPlaces.chunked(into: batchSize)
        
        var failedPlaceCount = 0
        for (batchIndex, batch) in batches.enumerated() {
            let batchFailed = try await Database.pool.write { db -> Int in
                var failed = 0
                for legacyPlace in batch {
                    do {
                        // skip-and-continue: an unexpected bad row must not abort the migration
                        try db.inSavepoint {
                            // Convert + save (RTree created automatically via trigger)
                            try Place(from: legacyPlace).insert(db, onConflict: .ignore)
                            return .commit
                        }
                    } catch {
                        failed += 1
                        Log.error("Skipping place \(legacyPlace.placeId) on import: \(error)", subsystem: .importing)
                    }
                }
                return failed
            }
            failedPlaceCount += batchFailed

            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage

            // Progress logging for debugging
            if batchIndex % 10 == 0 || batchIndex == batches.count - 1 {
                print("Imported places batch \(batchIndex + 1)/\(batches.count)")
            }
        }
        
        progress = 1.0
        if failedPlaceCount > 0 {
            Log.error("Places import skipped \(failedPlaceCount) unconvertible places", subsystem: .importing)
        }
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
        
        Log.info("Read \(legacyItems.count) timeline items from LocoKit database", subsystem: .importing)
        
        let totalCount = legacyItems.count
        
        // importedItemIds is set after the loop from successfully-imported items only,
        // so a skipped item's samples orphan (null parent) rather than FK-violating.
        
        // Import items in batches
        let batchSize = 200 // Smaller than places since items are more complex
        let batches = legacyItems.chunked(into: batchSize)

        // Build disabled states mapping as we import
        var itemDisabledStates: [String: Bool] = [:]
        var failedItemCount = 0

        for (batchIndex, batch) in batches.enumerated() {
            let (batchDisabledStates, batchFailed) = try await Database.pool.write { db -> ([String: Bool], Int) in
                var localStates: [String: Bool] = [:]
                var failed = 0

                for legacyItem in batch {
                    do {
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

                        // Create sanitised legacy item without edges for the init
                        var sanitisedLegacyItem = legacyItem
                        sanitisedLegacyItem.previousItemId = nil
                        sanitisedLegacyItem.nextItemId = nil

                        // Create TimelineItem from legacy item
                        let item = try TimelineItem(from: sanitisedLegacyItem)

                        var itemWasInserted = false

                        // Skip-and-continue: a bad item must not abort the migration. The
                        // savepoint keeps the item's base + visit/trip atomic on failure.
                        try db.inSavepoint {
                            try item.base.insert(db, onConflict: .ignore)
                            itemWasInserted = db.changesCount == 1 // .ignore no-ops leave it 0

                            // Save visit or trip component
                            if let visit = item.visit {
                                // check if placeId exists before saving
                                if let placeId = visit.placeId {
                                    let placeExists = try Place.filter { $0.id == placeId }.fetchCount(db) > 0
                                    if !placeExists {
                                        Log.info("Visit \(visit.itemId) references non-existent place: \(placeId)", subsystem: .importing)
                                        // clear the invalid place (placeless visits can't be confirmed, must be uncertain)
                                        var mutableVisit = visit
                                        mutableVisit.clearPlace()
                                        try mutableVisit.insert(db, onConflict: .ignore)
                                    } else {
                                        try visit.insert(db, onConflict: .ignore)
                                    }
                                } else {
                                    try visit.insert(db, onConflict: .ignore)
                                }
                            }
                            try item.trip?.insert(db, onConflict: .ignore)
                            return .commit
                        }

                        // BIG-629: only newly-inserted items get legacy edges restored — on a
                        // re-run, already-present items keep their current (possibly reshaped)
                        // edges rather than having stale legacy linkage re-imposed
                        if itemWasInserted {
                            try edgeManager.saveRecord(record)
                        }

                        // Track disabled state for sample import (only for imported items)
                        localStates[item.id] = item.base.disabled
                    } catch {
                        failed += 1
                        Log.error("Skipping item \(legacyItem.itemId) on import: \(error)", subsystem: .importing)
                    }
                }

                return (localStates, failed)
            }

            // Merge batch disabled states into main collection
            itemDisabledStates.merge(batchDisabledStates) { (_, new) in new }
            failedItemCount += batchFailed

            // Update progress
            let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
            progress = completedPercentage / 2 // First half of the process

            // Progress logging for debugging
            if batchIndex % 20 == 0 || batchIndex == batches.count - 1 {
                print("Imported timeline items batch \(batchIndex + 1)/\(batches.count)")
            }
        }
        
        // Restore edge relationships
        Log.info("Restoring timeline item edge relationships", subsystem: .importing)
        try await edgeManager.restoreEdgeRelationships { progressPercentage in
            // Update progress (second half of process)
            progress = 0.5 + (progressPercentage / 2)
        }
        
        // Cleanup
        edgeManager.cleanup()
        
        progress = 1.0
        if failedItemCount > 0 {
            Log.error("Timeline Items import skipped \(failedItemCount) unconvertible items", subsystem: .importing)
        }
        Log.info("Timeline Items import completed", subsystem: .importing)

        // BIG-629: derive sample-parent truth from the main db, not the legacy walk. On a
        // re-run, already-present items may have since been deleted or disabled by timeline
        // processing and user edits — assigning samples against the legacy view violates the
        // parent-state triggers and swallows whole sample batches. The main db's live items
        // are the authoritative parent set: samples of since-deleted parents orphan (and get
        // rebuilt homes), and disabled-state alignment uses the parents' current values.
        let currentStates = try await Database.pool.read { db -> [String: Bool] in
            let request = TimelineItemBase
                .filter { $0.deleted == false }
                .select { [$0.id, $0.disabled] }
            var states = [String: Bool]()
            for row in try Row.fetchAll(db, request) {
                let id: String = row[0]
                states[id] = row[1]
            }
            return states
        }
        importedItemIds = Set(currentStates.keys)
        return (totalCount, importedItemIds, currentStates)
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
        
        Log.info("Found \(totalCount) non-deleted samples (rowid range: \(minRowId)-\(maxRowId))", subsystem: .importing)

        let batchSize = 1000
        var currentRowId = resumeFromRowId.map { $0 + 1 } ?? minRowId
        var processedCount = 0
        var failedBatchCount = 0
        var skippedSampleCount = 0

        // Process in rowid-range batches
        while currentRowId <= maxRowId {
            let batchEndRowId = min(currentRowId + batchSize - 1, maxRowId)

            do {
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

                    } catch {
                        // BIG-629: a batch-level failure must not cost the whole batch (the
                        // "Shape-2 swallow" that silently dropped whole ranges). Rescue
                        // per-sample: each sample retries individually, falling back to
                        // orphaning (nulled parent, rebuilt home) before giving up on it.
                        failedBatchCount += 1
                        Log.error("Sample batch failed (rowids \(currentRowId)-\(batchEndRowId)), rescuing per-sample: \(error)", subsystem: .importing)
                        let result = await rescueSampleBatch(
                            batch,
                            importedItemIds: importedItemIds,
                            itemDisabledStates: itemDisabledStates,
                            orphanedSamples: &orphanedSamples,
                            disabledSamplesFromEnabledParents: &disabledSamplesFromEnabledParents
                        )
                        processedCount += result.rescued + result.orphaned
                        skippedSampleCount += result.skipped
                        Log.info("Batch rescue: \(result.rescued) rescued, \(result.orphaned) orphaned, \(result.skipped) unrecoverable of \(batch.count)", subsystem: .importing)
                    }

                    try await OldLocoKitImportState.updateLastProcessedSampleRowId(batchEndRowId)

                    // Progress logging every 100 batches (100k samples)
                    if (currentRowId / batchSize) % 100 == 0 {
                        print("Processed \(processedCount) samples...")
                    }
                }
            } catch {
                failedBatchCount += 1
                Log.error("Sample batch read failed (rowids \(currentRowId)-\(batchEndRowId)): \(error)", subsystem: .importing)
            }

            // Update progress based on rowid position
            progress = Double(currentRowId - minRowId) / Double(maxRowId - minRowId)

            // Move to next batch
            currentRowId = batchEndRowId + 1
        }

        if failedBatchCount > 0 {
            Log.error("Sample import: \(failedBatchCount) batches went through per-sample rescue; \(skippedSampleCount) samples unrecoverable, \(processedCount) imported", subsystem: .importing)
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

    /// BIG-629: per-sample rescue for a failed batch. Retries each sample individually,
    /// then falls back to orphaning it (nulled parent; the orphan processor rebuilds a home)
    /// so credible data isn't discarded over a parent-state conflict. Only samples the
    /// schema intrinsically rejects are skipped.
    private static func rescueSampleBatch(
        _ batch: [LegacySample],
        importedItemIds: Set<String>,
        itemDisabledStates: [String: Bool],
        orphanedSamples: inout [String: [LocomotionSample]],
        disabledSamplesFromEnabledParents: inout [String: [LocomotionSample]]
    ) async -> (rescued: Int, orphaned: Int, skipped: Int) {
        var rescued = 0, orphaned = 0, skipped = 0
        for legacySample in batch {
            do {
                try await processLegacySampleBatch(
                    [legacySample],
                    importedItemIds: importedItemIds,
                    itemDisabledStates: itemDisabledStates,
                    orphanedSamples: &orphanedSamples,
                    disabledSamplesFromEnabledParents: &disabledSamplesFromEnabledParents
                )
                rescued += 1

            } catch {
                do {
                    var sample = LocomotionSample(from: legacySample)
                    let originalParentId = sample.timelineItemId
                    sample.timelineItemId = nil
                    let orphanSample = sample
                    try await Database.pool.write { db in
                        try orphanSample.insert(db, onConflict: .ignore)
                    }
                    if let originalParentId {
                        orphanedSamples[originalParentId, default: []].append(orphanSample)
                    }
                    orphaned += 1

                } catch {
                    skipped += 1
                    Log.error("Sample \(legacySample.sampleId) unrecoverable on import: \(error)", subsystem: .importing)
                }
            }
        }
        return (rescued, orphaned, skipped)
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
