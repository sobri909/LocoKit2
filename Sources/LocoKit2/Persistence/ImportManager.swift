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
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw ImportError.missingMetadata
        }
        
        guard FileManager.default.fileExists(atPath: placesURL.path) else {
            throw ImportError.missingPlacesDirectory
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
    
    private func cleanupFailedImport() {
        importInProgress = false
        importURL = nil
    }
}

// MARK: -

enum ImportError: Error {
    case missingMetadata
    case missingPlacesDirectory
}
