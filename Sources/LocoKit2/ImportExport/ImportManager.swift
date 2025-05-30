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

    private(set) static var importInProgress = false
    private static var importURL: URL?
    private static var bookmarkData: Data?
    
    // MARK: - Import process
    
    public static func startImport(withBookmark bookmark: Data) async throws {
        guard !importInProgress else {
            throw ImportExportError.importInProgress
        }
        
        let startTime = Date()
        importInProgress = true
        bookmarkData = bookmark
        
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
            let itemsCount = try await importTimelineItems(edgeManager: edgeManager)
            let (samplesCount, orphansProcessed) = try await importSamples()
            
            // Log import summary
            let duration = Date().timeIntervalSince(startTime)
            let durationString = String(format: "%.1f", duration)
            var summary = "ImportManager completed successfully in \(durationString)s: "
            summary += "\(placesCount) places, \(itemsCount) items, \(samplesCount) samples"
            if orphansProcessed > 0 {
                summary += " (processed \(orphansProcessed) orphaned samples)"
            }
            logger.info(summary, subsystem: .database)
            
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
        logger.info("ImportManager: Import metadata loaded - schema: \(metadata.schemaVersion), mode: \(metadata.exportMode.rawValue)", subsystem: .database)

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
                logger.error("Failed to read metadata", subsystem: .database)
                logger.error(error, subsystem: .database)
            }
        }

        if let coordError {
            logger.error("File coordination failed", subsystem: .database)
            logger.error(coordError, subsystem: .database)
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

        logger.info("ImportManager: Starting places import (\(placeFiles.count) files)", subsystem: .database)

        var totalPlaces = 0
        
        for fileURL in placeFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let places = try JSONDecoder().decode([Place].self, from: fileData)
                print("Loaded \(places.count) places from \(fileURL.lastPathComponent)")
                
                try await Database.pool.uncancellableWrite { db in
                    for place in places {
                        try place.save(db)
                    }
                }
                totalPlaces += places.count
            } catch {
                logger.error(error, subsystem: .database)
                continue
            }
        }
        
        logger.info("ImportManager: Places import complete (\(totalPlaces) places)", subsystem: .database)
        return totalPlaces
    }

    // MARK: - Items

    private static func importTimelineItems(edgeManager: EdgeRecordManager) async throws -> Int {
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

        logger.info("ImportManager: Starting timeline items import (\(itemFiles.count) files)", subsystem: .database)

        var totalItems = 0
        // Process monthly files
        for fileURL in itemFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let items = try JSONDecoder().decode([TimelineItem].self, from: fileData)
                print("Loaded \(items.count) items from \(fileURL.lastPathComponent)")
                totalItems += items.count

                // Process in batches of 100
                for batch in items.chunked(into: 100) {
                    try await Database.pool.uncancellableWrite { db in
                        // collect all placeIds referenced by Visits in this batch
                        let placeIds = Set(batch.compactMap { $0.visit?.placeId }).filter { !$0.isEmpty }
                        
                        // check which ones exist in the database
                        let validPlaceIds = try String.fetchSet(db, Place
                            .select(Column("id"))
                            .filter(placeIds.contains(Column("id"))))
                        
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

                            try mutableBase.save(db)
                            
                            // handle Visits with missing Places
                            if var visit = item.visit {
                                if let placeId = visit.placeId, !validPlaceIds.contains(placeId) {
                                    logger.error("Detached visit with missing place: \(placeId)", subsystem: .database)
                                    visit.placeId = nil
                                    visit.confirmedPlace = false
                                    visit.uncertainPlace = true
                                }
                                try visit.save(db)
                                
                            } else {
                                try item.visit?.save(db)
                            }
                            
                            try item.trip?.save(db)
                        }
                    }
                }
            } catch {
                logger.error(error, subsystem: .database)
                continue // Log and continue on file errors
            }
        }
        
        // Now restore edge relationships using the EdgeRecordManager
        try await restoreEdgeRelationships(using: edgeManager)
        
        logger.info("ImportManager: Timeline items import complete (\(totalItems) items)", subsystem: .database)
        return totalItems
    }

    private static func restoreEdgeRelationships(using edgeManager: EdgeRecordManager) async throws {
        logger.info("ImportManager: Restoring edge relationships", subsystem: .database)
        
        // Use the EdgeRecordManager to restore relationships with progress tracking
        try await edgeManager.restoreEdgeRelationships { progressPercentage in
            // Could handle progress updates here if needed
        }
        
        logger.info("ImportManager: Edge restoration complete", subsystem: .database)
        
        // Clean up temporary files
        edgeManager.cleanup()
    }

    // MARK: - Samples

    private static func importSamples() async throws -> (samples: Int, orphansProcessed: Int) {
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

        logger.info("ImportManager: Starting samples import (\(sampleFiles.count) files)", subsystem: .database)
        
        var totalSamples = 0
        // track orphaned samples by their original parent timeline item ID
        var orphanedSamples: [String: [LocomotionSample]] = [:]

        // process each week's file
        for fileURL in sampleFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let samples = try JSONDecoder().decode([LocomotionSample].self, from: fileData)
                print("Loaded \(samples.count) samples from \(fileURL.lastPathComponent)")
                totalSamples += samples.count

                // process in batches of 100
                for batch in samples.chunked(into: 100) {
                    // process batch and collect orphaned samples
                    let batchOrphans = try await Database.pool.uncancellableWrite { db -> [String: [LocomotionSample]] in
                        // get all timeline item IDs referenced in this batch
                        let itemIds = Set(batch.compactMap(\.timelineItemId))
                        if itemIds.isEmpty { return [:] }

                        // find which of those IDs actually exist in the database
                        let validIds = try String.fetchSet(db, TimelineItemBase
                            .select(Column("id"))
                            .filter(itemIds.contains(Column("id"))))

                        // collect orphans within transaction scope
                        var batchOrphans: [String: [LocomotionSample]] = [:]
                        var orphanedCount = 0
                        
                        for var sample in batch {
                            // check and fix invalid references
                            if let originalItemId = sample.timelineItemId, !validIds.contains(originalItemId) {
                                // preserve sample with its original itemId for later recreation
                                batchOrphans[originalItemId, default: []].append(sample)
                                
                                // null the reference for database compliance
                                sample.timelineItemId = nil
                                orphanedCount += 1
                            }

                            try sample.save(db)
                        }
                        
                        if orphanedCount > 0 {
                            logger.error("Orphaned \(orphanedCount) samples with missing parent items", subsystem: .database)
                        }
                        
                        // return the orphans so they can be merged outside the transaction
                        return batchOrphans
                    }
                    
                    // merge batch orphans into the main collection
                    for (itemId, samples) in batchOrphans {
                        orphanedSamples[itemId, default: []].append(contentsOf: samples)
                    }
                }

            } catch {
                logger.error(error, subsystem: .database)
                continue
            }
        }
        
        // process orphaned samples after all imports complete
        var totalOrphansProcessed = 0
        if !orphanedSamples.isEmpty {
            let totalOrphans = orphanedSamples.values.reduce(0) { $0 + $1.count }
            logger.info("ImportManager found orphaned samples for \(orphanedSamples.count) missing items (\(totalOrphans) samples total)", subsystem: .database)
            let (recreated, individual) = try await OrphanedSampleProcessor.processOrphanedSamples(orphanedSamples)
            logger.info("ImportManager orphan processing complete: \(recreated) items recreated, \(individual) individual items", subsystem: .database)
            totalOrphansProcessed = totalOrphans
        }
        
        logger.info("ImportManager: Samples import complete (\(totalSamples) samples)", subsystem: .database)
        return (totalSamples, totalOrphansProcessed)
    }
    
    // MARK: - Cleanup

    private static func cleanupSuccessfulImport() {
        if let importURL {
            importURL.stopAccessingSecurityScopedResource()
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
        importInProgress = false
        importURL = nil
        bookmarkData = nil
    }
}

// MARK: -
