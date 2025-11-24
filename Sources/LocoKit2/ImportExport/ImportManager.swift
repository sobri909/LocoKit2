//
//  ImportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-09.
//

import Foundation
import GRDB

@ImportExportActor
public enum ImportManager {

    // MARK: - Import state

    public private(set) static var importInProgress = false
    public private(set) static var currentPhase: ImportPhase?
    public private(set) static var progress: Double = 0

    public enum ImportPhase: Sendable {
        case validating
        case importingPlaces
        case importingItems
        case importingSamples
        case processingOrphans
    }

    private static var importURL: URL?
    private static var bookmarkData: Data?
    private static var wasObserving: Bool = true
    private static var wasRecording: Bool = false
    
    // MARK: - Import process
    
    public static func startImport(withBookmark bookmark: Data) async throws {
        guard !importInProgress else {
            throw ImportExportError.importInProgress
        }
        
        let startTime = Date()
        importInProgress = true
        currentPhase = .validating
        progress = 0
        bookmarkData = bookmark

        // save initial states and disable observation/recording during import
        wasObserving = TimelineObserver.highlander.enabled
        wasRecording = await TimelineRecorder.isRecording
        TimelineObserver.highlander.enabled = false
        await TimelineRecorder.stopRecording()
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
            cleanupFailedImport()
            throw ImportExportError.invalidBookmark
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            cleanupFailedImport()
            throw ImportExportError.securityScopeAccessDenied
        }
        
        importURL = url
        
        do {
            try await validateImportDirectory()
            let placesCount = try await importPlaces()
            
            let edgeManager = EdgeRecordManager()
            let (itemsCount, timelineItemIds, itemDisabledStates) = try await importTimelineItems(edgeManager: edgeManager)
            let (samplesCount, orphansProcessed) = try await importSamples(timelineItemIds: timelineItemIds, itemDisabledStates: itemDisabledStates)
            
            // Log import summary
            let duration = Date().timeIntervalSince(startTime)
            let durationString = String(format: "%.1f", duration)
            var summary = "ImportManager completed successfully in \(durationString)s: "
            summary += "\(placesCount) places, \(itemsCount) items, \(samplesCount) samples"
            if orphansProcessed > 0 {
                summary += " (processed \(orphansProcessed) orphaned samples)"
            }
            logger.info(summary, subsystem: .importing)
            
            // Clear import state
            cleanupSuccessfulImport()
            
        } catch {
            cleanupFailedImport()
            throw error
        }
    }
    
    private static func validateImportDirectory() async throws {
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
    }

    private static func readImportMetadata(from metadataURL: URL) async throws -> ExportMetadata {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var metadata: ExportMetadata?
        
        coordinator.coordinate(readingItemAt: metadataURL, error: &coordError) { url in
            do {
                let data = try Data(contentsOf: url)
                metadata = try JSONDecoder().decode(ExportMetadata.self, from: data)
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
                let places = try JSONDecoder().decode([Place].self, from: fileData)
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
                let items = try JSONDecoder().decode([TimelineItem].self, from: fileData)
                print("Loaded \(items.count) items from \(fileURL.lastPathComponent)")
                totalItems += items.count

                // Collect all timeline item IDs for later reference validation
                allTimelineItemIds.formUnion(items.map { $0.id })
                
                // Process in batches of 500 (matching OldLocoKitImporter)
                for batch in items.chunked(into: 500) {
                    let batchDisabledStates = try await Database.pool.uncancellableWrite { db -> [String: Bool] in
                        var localStates: [String: Bool] = [:]

                        // collect all placeIds referenced by Visits in this batch
                        let placeIds = Set(batch.compactMap { $0.visit?.placeId }).filter { !$0.isEmpty }

                        // check which ones exist in the database
                        let validPlaceIds = try String.fetchSet(db, Place
                            .select(\.id)
                            .filter { placeIds.contains($0.id) })

                        for item in batch {
                            // Store edge record before nulling the relationships
                            let record = EdgeRecordManager.EdgeRecord(
                                itemId: item.id,
                                previousId: item.base.previousItemId,
                                nextId: item.base.nextItemId
                            )

                            // Save edge record using EdgeRecordManager
                            try edgeManager.saveRecord(record)

                            // Clear edges for initial import
                            var mutableBase = item.base
                            mutableBase.previousItemId = nil
                            mutableBase.nextItemId = nil

                            try mutableBase.insert(db, onConflict: .ignore)

                            // track disabled state for sample import
                            localStates[item.id] = item.base.disabled

                            // handle Visits with missing Places
                            if var visit = item.visit {
                                if let placeId = visit.placeId, !validPlaceIds.contains(placeId) {
                                    logger.error("Detached visit with missing place: \(placeId)", subsystem: .database)
                                    visit.placeId = nil
                                    visit.confirmedPlace = false
                                    visit.uncertainPlace = true
                                }
                                try visit.insert(db, onConflict: .ignore)

                            } else if let visit = item.visit {
                                try visit.insert(db, onConflict: .ignore)
                            }

                            if let trip = item.trip {
                                try trip.insert(db, onConflict: .ignore)
                            }
                        }

                        return localStates
                    }

                    // merge batch disabled states into main collection
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
        let sampleFiles = try FileManager.default
            .contentsOfDirectory(
                at: samplesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        currentPhase = .importingSamples
        progress = 0

        logger.info("ImportManager: Starting samples import (\(sampleFiles.count) files)", subsystem: .importing)

        var totalSamples = 0
        var processedFiles = 0
        let totalFiles = sampleFiles.count
        // track orphaned samples by their original parent timeline item ID
        var orphanedSamples: [String: [LocomotionSample]] = [:]

        // track disabled samples from enabled parents (scenario 2) for preserved parent creation
        var disabledSamplesFromEnabledParents: [String: [LocomotionSample]] = [:]

        // process each week's file
        for fileURL in sampleFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let samples = try JSONDecoder().decode([LocomotionSample].self, from: fileData)
                print("Loaded \(samples.count) samples from \(fileURL.lastPathComponent)")
                totalSamples += samples.count

                // process in batches of 1000 (matching OldLocoKitImporter)
                for batch in samples.chunked(into: 1000) {
                    // process batch and collect orphaned samples / mismatches
                    let (batchOrphans, batchScenario2, _, _, _) = try await Database.pool.uncancellableWrite { [timelineItemIds, itemDisabledStates] db in
                        // collect orphans and scenario 2 mismatches within transaction scope
                        var batchOrphans: [String: [LocomotionSample]] = [:]
                        var batchScenario2: [String: [LocomotionSample]] = [:]
                        var orphanedCount = 0
                        var scenario1Count = 0
                        var scenario2Count = 0

                        for var sample in batch {
                            // check for disabled state mismatches
                            if let itemId = sample.timelineItemId, let itemDisabled = itemDisabledStates[itemId] {
                                if itemDisabled && !sample.disabled {
                                    // scenario 1: item disabled, sample enabled → force sample to disabled
                                    sample.disabled = true
                                    scenario1Count += 1

                                } else if !itemDisabled && sample.disabled {
                                    // scenario 2: item enabled, sample disabled → collect for preserved parent creation
                                    batchScenario2[itemId, default: []].append(sample)
                                    scenario2Count += 1
                                    // orphan from current parent (will be reassigned to preserved parent later)
                                    sample.timelineItemId = nil
                                }
                            }

                            // check and fix invalid references using pre-collected IDs
                            if let originalItemId = sample.timelineItemId, !timelineItemIds.contains(originalItemId) {
                                // preserve sample with its original itemId for later recreation
                                batchOrphans[originalItemId, default: []].append(sample)

                                // null the reference for database compliance
                                sample.timelineItemId = nil
                                orphanedCount += 1
                            }

                            try sample.insert(db, onConflict: .ignore)
                        }

                        if orphanedCount > 0 {
                            logger.error("Orphaned \(orphanedCount) samples with missing parent items", subsystem: .importing)
                        }

                        // log disabled state mismatches
                        if scenario1Count > 0 {
                            logger.info("Normalized \(scenario1Count) samples (scenario 1: item.disabled=true, sample.disabled=false)", subsystem: .importing)
                        }
                        if scenario2Count > 0 {
                            logger.info("Collected \(scenario2Count) samples for preserved parent creation (scenario 2: item.disabled=false, sample.disabled=true)", subsystem: .importing)
                        }

                        // return the orphans and mismatches so they can be merged outside the transaction
                        return (batchOrphans, batchScenario2, orphanedCount, scenario1Count, scenario2Count)
                    }

                    // merge batch orphans into the main collection
                    for (itemId, samples) in batchOrphans {
                        orphanedSamples[itemId, default: []].append(contentsOf: samples)
                    }

                    // merge batch scenario 2 mismatches into the main collection
                    for (itemId, samples) in batchScenario2 {
                        disabledSamplesFromEnabledParents[itemId, default: []].append(contentsOf: samples)
                    }
                }
                
                processedFiles += 1
                progress = Double(processedFiles) / Double(totalFiles)

                // Log progress every 50 files
                if processedFiles % 50 == 0 {
                    logger.info("ImportManager: Samples import progress - processed \(processedFiles)/\(sampleFiles.count) files, \(totalSamples) samples", subsystem: .importing)
                }

            } catch {
                logger.error(error, subsystem: .importing)
                continue
            }
        }

        // Create preserved parent items for scenario 2 mismatches
        if !disabledSamplesFromEnabledParents.isEmpty {
            try await ImportHelpers.createPreservedParentItems(for: disabledSamplesFromEnabledParents)
        }

        // process orphaned samples after all imports complete
        currentPhase = .processingOrphans
        progress = 0

        var totalOrphansProcessed = 0
        if !orphanedSamples.isEmpty {
            let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
            logger.info("ImportManager found orphaned samples for \(orphanedSamples.count) missing items (\(totalOrphans) samples total)", subsystem: .importing)
            let (recreated, individual) = try await OrphanedSampleProcessor.processOrphanedSamples(orphanedSamples)
            logger.info("ImportManager orphan processing complete: \(recreated) items recreated, \(individual) individual items", subsystem: .importing)
            totalOrphansProcessed = totalOrphans
        }
        
        logger.info("ImportManager: Samples import complete (\(totalSamples) samples)", subsystem: .importing)
        return (totalSamples, totalOrphansProcessed)
    }
    
    // MARK: - Cleanup

    private static func cleanupSuccessfulImport() {
        if let importURL {
            importURL.stopAccessingSecurityScopedResource()
        }

        // restore observation/recording to initial states
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            Task { await TimelineRecorder.startRecording() }
        }

        importInProgress = false
        importURL = nil
        bookmarkData = nil
    }

    private static func cleanupFailedImport() {
        if let importURL {
            importURL.stopAccessingSecurityScopedResource()
            
            // Clean up edge records file if it exists
            let edgesURL = importURL.appendingPathComponent("edge_records.jsonl")
            try? FileManager.default.removeItem(at: edgesURL)
        }

        // restore observation/recording to initial states
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            Task { await TimelineRecorder.startRecording() }
        }

        importInProgress = false
        importURL = nil
        bookmarkData = nil
    }
}

// MARK: -
