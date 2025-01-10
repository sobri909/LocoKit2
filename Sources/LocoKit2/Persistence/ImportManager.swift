//
//  ImportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-09.
//

import Foundation
import GRDB

@PersistenceActor
public final class ImportManager {
    public static let highlander = ImportManager()
    
    private(set) var importInProgress = false
    private var importURL: URL?
    
    // MARK: - Import process
    
    public func startImport(from exportURL: URL) async throws {
        guard !importInProgress else {
            throw PersistenceError.importInProgress
        }
        
        importInProgress = true
        importURL = exportURL
        
        do {
            try await validateImportDirectory()
            try await importPlaces()
            try await importTimelineItems()
            
            // Clear import state
            importInProgress = false
            importURL = nil
            
        } catch {
            cleanupFailedImport()
            throw error
        }
    }
    
    private func validateImportDirectory() async throws {
        guard let importURL else {
            throw PersistenceError.importNotInitialised
        }
        
        // Check for required structure
        let metadataURL = importURL.appendingPathComponent("metadata.json")
        let placesURL = importURL.appendingPathComponent("places", isDirectory: true)
        let itemsURL = importURL.appendingPathComponent("items", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw PersistenceError.missingMetadata
        }
        
        guard FileManager.default.fileExists(atPath: placesURL.path) else {
            throw PersistenceError.missingPlacesDirectory
        }
        
        guard FileManager.default.fileExists(atPath: itemsURL.path) else {
            throw PersistenceError.missingItemsDirectory
        }
        
        // Load and validate metadata
        let metadata = try JSONDecoder().decode(ExportMetadata.self,
            from: try Data(contentsOf: metadataURL))
        
        // TODO: Version check would go here when we add schema versioning
        print("Import metadata loaded: \(metadata)")
    }
    
    private func importPlaces() async throws {
        let placesURL = importURL!.appendingPathComponent("places")
        
        let placeFiles = try FileManager.default.contentsOfDirectory(
            at: placesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        try await Database.pool.write { db in
            for fileURL in placeFiles {
                do {
                    let placeData = try Data(contentsOf: fileURL)
                    var place = try JSONDecoder().decode(Place.self, from: placeData)
                    
                    // If place exists, update it, otherwise insert
                    if let existing = try Place.filter(Column("id") == place.id).fetchOne(db) {
                        try existing.updateChanges(db) {
                            $0 = place
                        }
                    } else {
                        try place.insert(db)
                    }
                    
                } catch {
                    logger.error(error, subsystem: .database)
                    continue // Log and continue on errors
                }
            }
        }
    }
    
    // MARK: - Error handling
    
    private func importTimelineItems() async throws {
        let itemsURL = importURL!.appendingPathComponent("items")
        let edgesURL = importURL!.appendingPathComponent("edge_records.jsonl")
        
        // Get the monthly item files in chronological order
        let itemFiles = try FileManager.default.contentsOfDirectory(
            at: itemsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted() // filenames are YYYY-MM.json so string sort works
        
        // Remove any existing edge records file
        try? FileManager.default.removeItem(at: edgesURL)
        
        // Process monthly files
        for fileURL in itemFiles {
            do {
                let itemsData = try Data(contentsOf: fileURL)
                let items = try JSONDecoder().decode([TimelineItemBase].self, from: itemsData)
                
                // Process in batches of 100
                for batch in items.chunked(into: 100) {
                    try await Database.pool.write { db in
                        for var item in batch {
                            // Store edge record before nulling the relationships
                            let record = EdgeRecord(
                                itemId: item.id,
                                previousId: item.previousItemId,
                                nextId: item.nextItemId
                            )
                            if let data = try? JSONEncoder().encode(record) {
                                try data.append(to: edgesURL)
                            }
                            
                            // Clear edges for initial import
                            item.previousItemId = nil
                            item.nextItemId = nil
                            
                            // Upsert pattern
                            if let existing = try TimelineItemBase.filter(Column("id") == item.id).fetchOne(db) {
                                try existing.updateChanges(db) {
                                    $0 = item
                                }
                            } else {
                                try item.insert(db)
                            }
                        }
                    }
                }
            } catch {
                logger.error(error, subsystem: .database)
                continue // Log and continue on file errors
            }
        }
    }
    
    private func cleanupFailedImport() {
        importInProgress = false
        importURL = nil
        
        // Clean up edge records file if it exists
        if let importURL {
            let edgesURL = importURL.appendingPathComponent("edge_records.jsonl")
            try? FileManager.default.removeItem(at: edgesURL)
        }
    }
}

// MARK: -

private struct EdgeRecord: Codable {
    let itemId: String
    let previousId: String?
    let nextId: String?
}
