//
//  ImportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-09.
//

import Foundation
import GRDB

// MARK: - Extension Protocol

public protocol ImportExtensionHandler: Sendable {
    var identifier: String { get }
    func `import`(from directory: URL) async throws -> Int
}

// MARK: -

@ImportExportActor
public enum ImportManager {

    // MARK: - Import state

    public private(set) static var importInProgress = false
    public private(set) static var currentPhase: ImportPhase?
    public private(set) static var progress: Double = 0

    public enum ImportPhase: Sendable {
        case copying
        case validating
        case importingPlaces
        case importingItems
        case importingSamples
        case processingOrphans
    }

    private static var importURL: URL?
    private static var wasObserving: Bool = true
    private static var wasRecording: Bool = false

    // MARK: - Import process

    /// Start a new import from a source URL (copies to local first)
    public static func startImport(
        from sourceURL: URL,
        extensions: [ImportExtensionHandler] = []
    ) async throws {
        guard !importInProgress else {
            throw ImportExportError.importInProgress
        }

        let startTime = Date()
        importInProgress = true
        currentPhase = .copying
        progress = 0

        // save initial states and disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()

        // copy source to local container (this may trigger iCloud downloads)
        let localURL: URL
        do {
            localURL = try await copyToLocal(from: sourceURL)
        } catch {
            cleanupFailedCopy()
            throw error
        }

        // stop accessing source - we now have local copy
        sourceURL.stopAccessingSecurityScopedResource()

        importURL = localURL

        do {
            currentPhase = .validating
            let metadata = try await validateImportDirectory()

            // save import state for resume capability (copy is complete)
            let relativePath = localURL.lastPathComponent
            let state = ImportState(
                exportId: metadata.exportId,
                startedAt: startTime,
                phase: .places,
                localCopyPath: relativePath
            )
            try await ImportState.save(state)

            try await performImportPhases(extensions: extensions, startTime: startTime, isResume: false)

        } catch {
            cleanupFailedImport()
            throw error
        }
    }
    
    private static func validateImportDirectory() async throws -> ExportMetadata {
        guard let importURL else {
            throw ImportExportError.importNotInitialised
        }

        // Try coordinated read of metadata first
        let metadataURL = importURL.appendingPathComponent("metadata.json")
        let metadata = try await readImportMetadata(from: metadataURL)
        logger.info("ImportManager: Import metadata loaded - schema: \(metadata.schemaVersion), mode: \(metadata.exportMode.rawValue)", subsystem: .importing)

        // Now check directory structure
        let placesURL = importURL.appendingPathComponent("places", isDirectory: true)
        guard FileManager.default.fileExists(atPath: placesURL.path) else {
            throw ImportExportError.missingPlacesDirectory
        }

        let itemsURL = importURL.appendingPathComponent("items", isDirectory: true)
        guard FileManager.default.fileExists(atPath: itemsURL.path) else {
            throw ImportExportError.missingItemsDirectory
        }

        let samplesURL = importURL.appendingPathComponent("samples", isDirectory: true)
        guard FileManager.default.fileExists(atPath: samplesURL.path) else {
            throw ImportExportError.missingSamplesDirectory
        }

        return metadata
    }

    private static func readImportMetadata(from metadataURL: URL) async throws -> ExportMetadata {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var metadata: ExportMetadata?
        
        coordinator.coordinate(readingItemAt: metadataURL, error: &coordError) { url in
            do {
                let data = try Data(contentsOf: url)
                metadata = try JSONDecoder.flexibleDateDecoder().decode(ExportMetadata.self, from: data)
            } catch {
                logger.error("Failed to read metadata", subsystem: .importing)
                logger.error(error, subsystem: .importing)
            }
        }

        if let coordError {
            logger.error("File coordination failed", subsystem: .importing)
            logger.error(coordError, subsystem: .importing)
            throw ImportExportError.missingMetadata
        }

        guard let metadata else {
            throw ImportExportError.missingMetadata
        }

        return metadata
    }

    // MARK: - Import phases

    private static func performImportPhases(
        extensions: [ImportExtensionHandler],
        startTime: Date,
        isResume: Bool
    ) async throws {
        let placesCount = try await importPlaces()

        try await ImportState.updatePhase(.items)
        let edgeManager = EdgeRecordManager()
        let (itemsCount, timelineItemIds, itemDisabledStates) = try await importTimelineItems(edgeManager: edgeManager)

        try await ImportState.updatePhase(.samples)
        let (samplesCount, orphansProcessed) = try await importSamples(timelineItemIds: timelineItemIds, itemDisabledStates: itemDisabledStates)

        // run extension handlers
        try await ImportState.updatePhase(.extensions)
        for handler in extensions {
            let count = try await handler.import(from: importURL!)
            logger.info("ImportManager: Extension '\(handler.identifier)' imported \(count) records", subsystem: .importing)
        }

        // log import summary
        let duration = Date().timeIntervalSince(startTime)
        let durationString = String(format: "%.1f", duration)
        let prefix = isResume ? "ImportManager (resumed) completed in" : "ImportManager completed successfully in"
        var summary = "\(prefix) \(durationString)s: "
        summary += "\(placesCount) places, \(itemsCount) items, \(samplesCount) samples"
        if orphansProcessed > 0 {
            summary += " (processed \(orphansProcessed) orphaned samples)"
        }
        logger.info(summary, subsystem: .importing)

        await cleanupSuccessfulImport()
    }

    // MARK: - Places

    private static func importPlaces() async throws -> Int {
        guard let importURL else {
            throw ImportExportError.importNotInitialised
        }
        let placesURL = importURL.appendingPathComponent("places")

        // get all .json files in the places directory
        let placeFiles = try FileManager.default.contentsOfDirectory(
            at: placesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }

        currentPhase = .importingPlaces
        progress = 0

        logger.info("ImportManager: Starting places import (\(placeFiles.count) files)", subsystem: .importing)

        var totalPlaces = 0
        let totalFiles = placeFiles.count
        var processedFiles = 0

        for fileURL in placeFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let places = try JSONDecoder.flexibleDateDecoder().decode([Place].self, from: fileData)
                print("Loaded \(places.count) places from \(fileURL.lastPathComponent)")
                
                try await Database.pool.uncancellableWrite { db in
                    for place in places {
                        try place.insert(db, onConflict: .ignore)
                    }
                }
                totalPlaces += places.count

                processedFiles += 1
                progress = Double(processedFiles) / Double(totalFiles)
            } catch {
                logger.error(error, subsystem: .importing)
                continue
            }
        }
        
        logger.info("ImportManager: Places import complete (\(totalPlaces) places)", subsystem: .importing)
        return totalPlaces
    }

    // MARK: - Items

    private static func importTimelineItems(edgeManager: EdgeRecordManager) async throws -> (count: Int, itemIds: Set<String>, disabledStates: [String: Bool]) {
        guard let importURL else {
            throw ImportExportError.importNotInitialised
        }
        let itemsURL = importURL.appendingPathComponent("items")

        // Get the monthly item files in chronological order
        let itemFiles = try FileManager.default.contentsOfDirectory(
            at: itemsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        currentPhase = .importingItems
        progress = 0

        logger.info("ImportManager: Starting timeline items import (\(itemFiles.count) files)", subsystem: .importing)

        var totalItems = 0
        var allTimelineItemIds = Set<String>()
        var itemDisabledStates: [String: Bool] = [:]
        let totalFiles = itemFiles.count
        var processedFiles = 0

        // Process monthly files
        for fileURL in itemFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let items = try JSONDecoder.flexibleDateDecoder().decode([TimelineItem].self, from: fileData)
                print("Loaded \(items.count) items from \(fileURL.lastPathComponent)")
                totalItems += items.count

                // Collect all timeline item IDs for later reference validation
                allTimelineItemIds.formUnion(items.map { $0.id })
                
                // Process in batches of 500 (matching OldLocoKitImporter)
                for batch in items.chunked(into: 500) {
                    let batchDisabledStates = try await Database.pool.uncancellableWrite { db in
                        try processTimelineItemBatch(batch, edgeManager: edgeManager, db: db)
                    }
                    itemDisabledStates.merge(batchDisabledStates) { (_, new) in new }
                }

                processedFiles += 1
                progress = Double(processedFiles) / Double(totalFiles)
            } catch {
                logger.error(error, subsystem: .database)
                continue // Log and continue on file errors
            }
        }
        
        // Now restore edge relationships using the EdgeRecordManager
        try await restoreEdgeRelationships(using: edgeManager)

        logger.info("ImportManager: Timeline items import complete (\(totalItems) items)", subsystem: .importing)
        return (totalItems, allTimelineItemIds, itemDisabledStates)
    }

    private nonisolated static func processTimelineItemBatch(
        _ batch: [TimelineItem],
        edgeManager: EdgeRecordManager,
        db: GRDB.Database
    ) throws -> [String: Bool] {
        var disabledStates: [String: Bool] = [:]

        // collect all placeIds referenced by Visits in this batch
        let placeIds = Set(batch.compactMap { $0.visit?.placeId }).filter { !$0.isEmpty }

        // check which ones exist in the database
        let validPlaceIds = try String.fetchSet(db, Place
            .select(\.id)
            .filter { placeIds.contains($0.id) })

        for item in batch {
            try processTimelineItem(item, validPlaceIds: validPlaceIds, edgeManager: edgeManager, db: db)
            disabledStates[item.id] = item.base.disabled
        }

        return disabledStates
    }

    private nonisolated static func processTimelineItem(
        _ item: TimelineItem,
        validPlaceIds: Set<String>,
        edgeManager: EdgeRecordManager,
        db: GRDB.Database
    ) throws {
        // save edge record before nulling the relationships
        let record = EdgeRecordManager.EdgeRecord(
            itemId: item.id,
            previousId: item.base.previousItemId,
            nextId: item.base.nextItemId
        )
        try edgeManager.saveRecord(record)

        // clear edges and insert base
        var mutableBase = item.base
        mutableBase.previousItemId = nil
        mutableBase.nextItemId = nil
        try mutableBase.insert(db, onConflict: .ignore)

        // insert visit (handling missing places)
        if var visit = item.visit {
            if let placeId = visit.placeId, !validPlaceIds.contains(placeId) {
                logger.error("Detached visit with missing place: \(placeId)", subsystem: .database)
                visit.placeId = nil
                visit.confirmedPlace = false
                visit.uncertainPlace = true
            }
            try visit.insert(db, onConflict: .ignore)
        }

        // insert trip
        if let trip = item.trip {
            try trip.insert(db, onConflict: .ignore)
        }
    }

    private static func restoreEdgeRelationships(using edgeManager: EdgeRecordManager) async throws {
        logger.info("ImportManager: Restoring edge relationships", subsystem: .importing)
        
        // Use the EdgeRecordManager to restore relationships with progress tracking
        try await edgeManager.restoreEdgeRelationships { progressPercentage in
            // Could handle progress updates here if needed
        }
        
        logger.info("ImportManager: Edge restoration complete", subsystem: .importing)
        
        // Clean up temporary files
        edgeManager.cleanup()
    }

    // MARK: - Samples

    private static func importSamples(timelineItemIds: Set<String>, itemDisabledStates: [String: Bool]) async throws -> (samples: Int, orphansProcessed: Int) {
        guard let importURL else {
            throw ImportExportError.importNotInitialised
        }
        let samplesURL = importURL.appendingPathComponent("samples")

        // get the weekly sample files in chronological order
        // supports both .json.gz (compressed) and .json (legacy) formats
        let sampleFiles = try FileManager.default
            .contentsOfDirectory(
                at: samplesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "gz" || $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        currentPhase = .importingSamples
        progress = 0

        // get already-processed files from ImportState (for resume efficiency)
        let alreadyProcessed: Set<String>
        if let state = try? await ImportState.current(), let files = state.processedSampleFiles {
            alreadyProcessed = Set(files)
        } else {
            alreadyProcessed = []
        }

        let filesToProcess = sampleFiles.filter { !alreadyProcessed.contains($0.lastPathComponent) }
        logger.info("ImportManager: Starting samples import (\(filesToProcess.count) files, \(alreadyProcessed.count) already processed)", subsystem: .importing)

        var totalSamples = 0
        var processedFiles = 0
        let totalFiles = filesToProcess.count

        // process each week's file
        for fileURL in filesToProcess {
            // track per-file orphans for persistence
            var fileOrphans: [String: [LocomotionSample]] = [:]
            var fileScenario2: [String: [LocomotionSample]] = [:]

            do {
                let rawData = try Data(contentsOf: fileURL)
                let fileData = fileURL.pathExtension == "gz"
                    ? try rawData.gzipDecompressed()
                    : rawData
                let samples = try JSONDecoder.flexibleDateDecoder().decode([LocomotionSample].self, from: fileData)
                print("Loaded \(samples.count) samples from \(fileURL.lastPathComponent)")
                totalSamples += samples.count

                // process in batches of 1000
                for batch in samples.chunked(into: 1000) {
                    let batchResult = try await Database.pool.uncancellableWrite { [timelineItemIds, itemDisabledStates] db in
                        try SampleImportProcessor.processBatch(
                            samples: batch,
                            validItemIds: timelineItemIds,
                            itemDisabledStates: itemDisabledStates,
                            db: db
                        )
                    }

                    SampleImportProcessor.logBatchResults(batchResult)
                    SampleImportProcessor.mergeResults(batchResult, into: &fileOrphans, scenario2: &fileScenario2)
                }

                // persist orphans for resume
                if !fileOrphans.isEmpty || !fileScenario2.isEmpty {
                    OrphanMappingsManager.appendMappings(orphans: fileOrphans, scenario2: fileScenario2, to: importURL)
                }

                processedFiles += 1
                progress = Double(processedFiles) / Double(totalFiles)

                // mark file as processed for resume efficiency
                try await ImportState.markFileProcessed(fileURL.lastPathComponent)

                // log progress every 50 files
                if processedFiles % 50 == 0 {
                    logger.info("ImportManager: Samples import progress - processed \(processedFiles)/\(totalFiles) files, \(totalSamples) samples", subsystem: .importing)
                }

            } catch {
                logger.error(error, subsystem: .importing)
                continue
            }
        }

        // load all orphan mappings from file (source of truth across all runs)
        let persistedMappings = OrphanMappingsManager.loadMappings(from: importURL)
        var finalOrphans: [String: [LocomotionSample]] = [:]
        var finalScenario2: [String: [LocomotionSample]] = [:]

        if !persistedMappings.orphans.isEmpty || !persistedMappings.scenario2.isEmpty {
            let (restoredOrphans, restoredScenario2) = try await OrphanMappingsManager.reconstructOrphans(from: persistedMappings)
            finalOrphans = restoredOrphans
            finalScenario2 = restoredScenario2
            logger.info("Loaded \(persistedMappings.orphans.count) orphan groups and \(persistedMappings.scenario2.count) scenario2 groups from persisted mappings", subsystem: .importing)
        }

        // create preserved parent items for scenario 2 mismatches
        if !finalScenario2.isEmpty {
            try await ImportHelpers.createPreservedParentItems(for: finalScenario2)
        }

        // process orphaned samples after all imports complete
        currentPhase = .processingOrphans
        progress = 0

        var totalOrphansProcessed = 0
        if !finalOrphans.isEmpty {
            let totalOrphans = finalOrphans.values.reduce(0) { $0 + $1.count }
            logger.info("ImportManager found orphaned samples for \(finalOrphans.count) missing items (\(totalOrphans) samples total)", subsystem: .importing)
            let (recreated, individual) = try await OrphanedSampleProcessor.processOrphanedSamples(finalOrphans)
            logger.info("ImportManager orphan processing complete: \(recreated) items recreated, \(individual) individual items", subsystem: .importing)
            totalOrphansProcessed = totalOrphans
        }
        
        logger.info("ImportManager: Samples import complete (\(totalSamples) samples)", subsystem: .importing)
        return (totalSamples, totalOrphansProcessed)
    }
    
    // MARK: - Copy to Local

    private static func copyToLocal(from sourceURL: URL) async throws -> URL {
        let copyDir = ImportState.localCopyDirectory
        let destURL = copyDir.appendingPathComponent(UUID().uuidString, isDirectory: true)

        // remove any existing copy directory
        if FileManager.default.fileExists(atPath: copyDir.path) {
            try FileManager.default.removeItem(at: copyDir)
        }

        // create destination directory
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        logger.info("ImportManager: Copying backup to local container", subsystem: .importing)

        // enumerate all files in source directory (must collect before async loop)
        guard let enumerator = FileManager.default.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ImportExportError.importNotInitialised
        }

        var filesToCopy: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                filesToCopy.append(fileURL)
            }
        }

        let totalFiles = filesToCopy.count
        logger.info("ImportManager: Found \(totalFiles) files to copy", subsystem: .importing)

        // copy each file with progress updates
        for (index, fileURL) in filesToCopy.enumerated() {
            // get relative path from source
            let relativePath = fileURL.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
            let destFileURL = destURL.appendingPathComponent(relativePath)

            // create parent directory if needed
            let destParent = destFileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destParent.path) {
                try FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
            }

            // copy file
            try FileManager.default.copyItem(at: fileURL, to: destFileURL)

            // update progress and yield to allow actor access
            progress = Double(index + 1) / Double(totalFiles)
            await Task.yield()
        }

        logger.info("ImportManager: Copy complete", subsystem: .importing)

        return destURL
    }

    // MARK: - Resume Import

    /// Resume an interrupted import from local copy
    public static func resumeImport(
        extensions: [ImportExtensionHandler] = []
    ) async throws {
        guard !importInProgress else {
            throw ImportExportError.importInProgress
        }

        guard let state = try await ImportState.current(),
              let localURL = ImportState.localCopyURL(for: state) else {
            throw ImportExportError.importNotInitialised
        }

        // verify local copy still exists
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            try await ImportState.clear()
            throw ImportExportError.importNotInitialised
        }

        let startTime = Date()
        importInProgress = true
        currentPhase = .validating
        progress = 0
        importURL = localURL

        // disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()

        do {
            let metadata = try await validateImportDirectory()

            // validate exportId matches
            if let storedExportId = state.exportId, let metadataExportId = metadata.exportId {
                guard storedExportId == metadataExportId else {
                    throw ImportExportError.exportIdMismatch
                }
            }

            try await performImportPhases(extensions: extensions, startTime: startTime, isResume: true)

        } catch {
            cleanupFailedImport()
            throw error
        }
    }

    // MARK: - Cleanup

    private static func cleanupSuccessfulImport() async {
        // clear import state and delete local copy
        try? await ImportState.clear()
        ImportState.deleteLocalCopy()

        // restore observation/recording to initial states
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            try? await TimelineRecorder.startRecording()
        }

        importInProgress = false
        importURL = nil
    }

    private static func cleanupFailedImport() {
        if let importURL {
            // clean up edge records file if it exists
            let edgesURL = importURL.appendingPathComponent("edge_records.jsonl")
            try? FileManager.default.removeItem(at: edgesURL)
        }

        // don't restore recording - partial import blocks it until resolved
        // don't delete local copy - it's needed for resume
        TimelineObserver.highlander.enabled = wasObserving

        importInProgress = false
        self.importURL = nil
    }

    private static func cleanupFailedCopy() {
        // copy failed before ImportState was created
        // delete any partial copy
        ImportState.deleteLocalCopy()

        // restore observation/recording to initial states
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            Task { try? await TimelineRecorder.startRecording() }
        }

        importInProgress = false
        importURL = nil
    }
}
