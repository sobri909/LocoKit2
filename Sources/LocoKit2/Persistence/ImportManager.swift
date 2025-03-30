//
//  ImportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-09.
//

import Foundation
import GRDB

@PersistenceActor
public enum ImportManager {

    private(set) static var importInProgress = false
    private static var importURL: URL?
    private static var bookmarkData: Data?
    
    // MARK: - Import process
    
    public static func startImport(withBookmark bookmark: Data) async throws {
        guard !importInProgress else {
            throw PersistenceError.importInProgress
        }
        
        importInProgress = true
        bookmarkData = bookmark
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
            cleanupFailedImport()
            throw PersistenceError.invalidBookmark
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            cleanupFailedImport()
            throw PersistenceError.securityScopeAccessDenied
        }
        
        importURL = url
        
        do {
            try await validateImportDirectory()
            try await importPlaces()
            try await importTimelineItems()
            try await restoreEdgeRelationships()
            try await importSamples()
            
            // Clear import state
            cleanupSuccessfulImport()
            
        } catch {
            cleanupFailedImport()
            throw error
        }
    }
    
    private static func validateImportDirectory() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }

        // Try coordinated read of metadata first
        let metadataURL = importURL.appendingPathComponent("metadata.json")
        let metadata = try await readImportMetadata(from: metadataURL)
        print("Import metadata loaded: \(metadata)")

        // Now check directory structure
        let placesURL = importURL.appendingPathComponent("places", isDirectory: true)
        guard FileManager.default.fileExists(atPath: placesURL.path) else {
            throw PersistenceError.missingPlacesDirectory
        }

        let itemsURL = importURL.appendingPathComponent("items", isDirectory: true)
        guard FileManager.default.fileExists(atPath: itemsURL.path) else {
            throw PersistenceError.missingItemsDirectory
        }

        let samplesURL = importURL.appendingPathComponent("samples", isDirectory: true)
        guard FileManager.default.fileExists(atPath: samplesURL.path) else {
            throw PersistenceError.missingSamplesDirectory
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
                print("Failed to read metadata: \(error)")
            }
        }

        if let coordError {
            print("Coordination error: \(coordError)")
            throw PersistenceError.missingMetadata
        }

        guard let metadata else {
            throw PersistenceError.missingMetadata
        }

        return metadata
    }

    // MARK: - Places

    private static func importPlaces() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }
        let placesURL = importURL.appendingPathComponent("places")

        // get all .json files in the places directory
        let placeFiles = try FileManager.default.contentsOfDirectory(
            at: placesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }

        print("Found place files: \(placeFiles.count)")

        try await Database.pool.uncancellableWrite { db in
            for fileURL in placeFiles {
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let places = try JSONDecoder().decode([Place].self, from: fileData)
                    print("Loaded \(places.count) places from \(fileURL.lastPathComponent)")

                    for var place in places {
                        var rtree = PlaceRTree(
                            latMin: place.latitude,
                            latMax: place.latitude,
                            lonMin: place.longitude,
                            lonMax: place.longitude
                        )
                        try rtree.save(db)
                        place.rtreeId = rtree.id
                        try place.save(db)
                    }
                } catch {
                    logger.error(error, subsystem: .database)
                    continue
                }
            }
        }
    }

    // MARK: - Items

    private static func importTimelineItems() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }
        let itemsURL = importURL.appendingPathComponent("items")
        let edgesURL = importURL.appendingPathComponent("edge_records.jsonl")

        // Get the monthly item files in chronological order
        let itemFiles = try FileManager.default.contentsOfDirectory(
            at: itemsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        print("Found item files: \(itemFiles.count)")

        // Remove any existing edge records file
        try? FileManager.default.removeItem(at: edgesURL)

        // Process monthly files
        for fileURL in itemFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let items = try JSONDecoder().decode([TimelineItem].self, from: fileData)
                print("Loaded \(items.count) items from \(fileURL.lastPathComponent)")

                // Process in batches of 100
                for batch in items.chunked(into: 100) {
                    try await Database.pool.uncancellableWrite { db in
                        for item in batch {
                            // Store edge record before nulling the relationships
                            let record = EdgeRecord(
                                itemId: item.id,
                                previousId: item.base.previousItemId,
                                nextId: item.base.nextItemId
                            )

                            do {
                                let data = try JSONEncoder().encode(record)
                                try data.appendLine(to: edgesURL)
                            } catch {
                                logger.error("Failed to save edge record: \(error)", subsystem: .database)
                            }

                            // Clear edges for initial import
                            var mutableBase = item.base
                            mutableBase.previousItemId = nil
                            mutableBase.nextItemId = nil

                            try mutableBase.save(db)
                            try item.visit?.save(db)
                            try item.trip?.save(db)
                        }
                    }
                }
            } catch {
                logger.error(error, subsystem: .database)
                continue // Log and continue on file errors
            }
        }
    }

    private static func restoreEdgeRelationships() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }

        let edgesURL = importURL.appendingPathComponent("edge_records.jsonl")
        guard FileManager.default.fileExists(atPath: edgesURL.path) else {
            throw PersistenceError.missingEdgeRecords
        }

        let records = try await loadEdgeRecords(from: edgesURL)
        print("Loaded \(records.count) edge records")

        // Process records in batches to manage transaction size
        for batch in records.chunked(into: 100) {
            try await Database.pool.uncancellableWrite { db in
                for record in batch {
                    try TimelineItemBase
                        .filter(Column("id") == record.itemId)
                        .updateAll(db, [
                            Column("previousItemId").set(to: record.previousId),
                            Column("nextItemId").set(to: record.nextId)
                        ])
                }
            }
        }

        print("Edge restoration complete")

        // Clean up edge records file
        try? FileManager.default.removeItem(at: edgesURL)
    }

    private static func loadEdgeRecords(from url: URL) async throws -> [EdgeRecord] {
        var records: [EdgeRecord] = []
        
        // Read JSONL file line by line to avoid loading entire file into memory
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        while let line = try fileHandle.readLine() {
            if let data = line.data(using: .utf8),
               let record = try? JSONDecoder().decode(EdgeRecord.self, from: data) {
                records.append(record)
            }
        }
        
        return records
    }

    // MARK: - Samples

    private static func importSamples() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }
        let samplesURL = importURL.appendingPathComponent("samples")

        // Get the weekly sample files in chronological order
        let sampleFiles = try FileManager.default.contentsOfDirectory(
            at: samplesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        print("Found sample files: \(sampleFiles.count)")

        // Process each week's file
        for fileURL in sampleFiles {
            do {
                let fileData = try Data(contentsOf: fileURL)
                let samples = try JSONDecoder().decode([LocomotionSample].self, from: fileData)
                print("Loaded \(samples.count) samples from \(fileURL.lastPathComponent)")

                // Process in batches of 100
                for batch in samples.chunked(into: 100) {
                    try await Database.pool.uncancellableWrite { db in
                        // Get all timeline item IDs referenced in this batch
                        let itemIds = Set(batch.compactMap(\.timelineItemId))

                        // Find which of those IDs actually exist in the database
                        let validIds = try String.fetchSet(db, TimelineItemBase
                            .select(Column("id"))
                            .filter(itemIds.contains(Column("id"))))

                        // Process each sample, orphaning those with invalid item IDs
                        for var sample in batch {
                            if let itemId = sample.timelineItemId, !validIds.contains(itemId) {
                                logger.error("Orphaning sample due to missing parent item: \(itemId)")
                                sample.timelineItemId = nil
                            }

                            // Create RTree record if we have valid coordinates
                            if let coordinate = sample.coordinate, !sample.disabled {
                                var rtree = SampleRTree(
                                    latMin: coordinate.latitude,
                                    latMax: coordinate.latitude,
                                    lonMin: coordinate.longitude,
                                    lonMax: coordinate.longitude
                                )
                                try rtree.save(db)
                                sample.rtreeId = rtree.id
                            }

                            try sample.save(db)
                        }
                    }
                }
            } catch {
                logger.error(error, subsystem: .database)
                continue
            }
        }
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

private struct EdgeRecord: Codable {
    let itemId: String
    let previousId: String?
    let nextId: String?
}
