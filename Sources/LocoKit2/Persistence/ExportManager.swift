//
//  ExportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation
import GRDB

@PersistenceActor
public final class ExportManager {
    public static let highlander = ExportManager()

    private(set) var exportInProgress = false
    
    // MARK: - Export paths
    
    private var currentExportURL: URL?
    
    private var placesURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("places", isDirectory: true)
    }
    
    private var itemsURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("items", isDirectory: true)
    }
    
    private var samplesURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("samples", isDirectory: true)
    }
    
    // MARK: - Export process
    
    public func startExport() async throws {
        guard !exportInProgress else {
            throw PersistenceError.exportInProgress
        }
        
        exportInProgress = true
        
        // create root export dir with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: .now)
        
        // Get iCloud container root
        guard let iCloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw PersistenceError.iCloudNotAvailable
        }
        
        // Create exports dir under container root
        let exportsRoot = iCloudRoot.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportsRoot, withIntermediateDirectories: true)
        
        let rootURL = exportsRoot.appendingPathComponent("export-\(timestamp)", isDirectory: true)
        
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        currentExportURL = rootURL
        
        // create type dirs
        try FileManager.default.createDirectory(at: placesURL!, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: itemsURL!, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: samplesURL!, withIntermediateDirectories: true)
        
        // start with places export
        try await exportPlaces()
    }
    
    private func exportPlaces() async throws {
        guard let placesURL else {
            throw PersistenceError.exportNotInitialised
        }
        
        // get all places
        let places = try await Database.pool.read { db in
            try Place.fetchAll(db)
        }
        
        // export each place
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        for place in places {
            let placeURL = placesURL.appendingPathComponent("\(place.id).json")
            let data = try encoder.encode(place)
            try data.write(to: placeURL)
        }
    }
}

// MARK: -

enum PersistenceError: Error {
    case exportInProgress
    case exportNotInitialised
    case importInProgress
    case importNotInitialised
    case iCloudNotAvailable
}