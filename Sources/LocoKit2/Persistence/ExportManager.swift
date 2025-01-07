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
    
    private var metadataURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("metadata.json")
    }
    
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
        
        // Write initial metadata before starting export
        try await writeInitialMetadata()
        
        // start with places export
        try await exportPlaces()
    }
    
    private func exportSamples() async throws {
        guard let samplesURL else {
            throw PersistenceError.exportNotInitialised
        }
        
        // Get all samples ordered by date
        let samples = try await Database.pool.read { db in
            try LocomotionSample
                .order(Column("date").asc)
                .fetchAll(db)
        }
        
        // Group samples by week using UTC calendar
        var weekSamples: [String: [LocomotionSample]] = [:]
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        for sample in samples {
            let weekOfYear = calendar.component(.weekOfYear, from: sample.date)
            let year = calendar.component(.year, from: sample.date)
            let weekId = String(format: "%4d-%02d", year, weekOfYear)
            weekSamples[weekId, default: []].append(sample)
        }
        
        // Export each week's samples to its own file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        for (weekId, samples) in weekSamples {
            let weekURL = samplesURL.appendingPathComponent("\(weekId).json")
            let data = try encoder.encode(samples)
            try data.write(to: weekURL)
        }
        
        // Export complete - clear state
        exportInProgress = false
    }

    private func exportItems() async throws {
        guard let itemsURL else {
            throw PersistenceError.exportNotInitialised
        }
        
        // Get all timeline items with their full relationships loaded
        let items = try await Database.pool.read { db in
            try TimelineItem
                .itemRequest(includeSamples: false, includePlaces: false)
                .filter(Column("deleted") == false)
                .fetchAll(db)
        }
        
        // Export each item
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        for item in items {
            let itemURL = itemsURL.appendingPathComponent("\(item.id).json")
            let data = try encoder.encode(item)
            try data.write(to: itemURL)
        }

        // Continue with samples export
        try await exportSamples()
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

        // Continue with items export
        try await exportItems()
    }
    
    private func writeInitialMetadata() async throws {
        guard let metadataURL else {
            throw PersistenceError.exportNotInitialised
        }
        
        // Gather stats
        let (placeCount, itemCount, sampleCount) = try await Database.pool.read { db in
            let places = try Place.fetchCount(db)
            let items = try TimelineItemBase.fetchCount(db)
            let samples = try LocomotionSample.fetchCount(db)
            return (places, items, samples)
        }
        
        let stats = ExportStats(
            placeCount: placeCount,
            itemCount: itemCount,
            sampleCount: sampleCount
        )
        
        let metadata = ExportMetadata(
            exportDate: .now,
            version: LocomotionManager.locoKitVersion,
            stats: stats
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL)
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
