//
//  ExportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation
import GRDB

@PersistenceActor
public enum ExportManager {
    public static let schemaVersion = "2.0.0"

    private(set) static var exportInProgress = false

    // MARK: - Export paths

    private static var currentExportURL: URL?

    private static var metadataURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("metadata.json")
    }

    private static var placesURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("places", isDirectory: true)
    }

    private static var itemsURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("items", isDirectory: true)
    }

    private static var samplesURL: URL? {
        guard let currentExportURL else { return nil }
        return currentExportURL.appendingPathComponent("samples", isDirectory: true)
    }

    // MARK: - Export process

    public static func startExport() async throws {
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
            cleanupFailedExport()
            throw PersistenceError.iCloudNotAvailable
        }

        do {
            // Create Documents dir under container root if needed
            let documentsRoot = iCloudRoot.appendingPathComponent("Documents", isDirectory: true)
            try FileManager.default.createDirectory(at: documentsRoot, withIntermediateDirectories: true)

            // Create exports dir under Documents
            let exportsRoot = documentsRoot.appendingPathComponent("Exports", isDirectory: true)
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
        } catch {
            cleanupFailedExport()
            throw error
        }
    }

    // MARK: - Metadata

    private static func writeInitialMetadata() async throws {
        guard let metadataURL else {
            throw PersistenceError.exportNotInitialised
        }

        // Gather stats
        let (placeCount, itemCount, sampleCount) = try await Database.pool.uncancellableRead { db in
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
            schemaVersion: ExportManager.schemaVersion,
            exportMode: .bucketed,
            exportType: .full,
            sessionStartDate: .now,
            sessionFinishDate: nil, // will be set when export completes
            itemsCompleted: false,
            placesCompleted: false,
            samplesCompleted: false,
            stats: stats
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL)
    }

    // MARK: - Places

    private static func exportPlaces() async throws {
        guard let placesURL else {
            throw PersistenceError.exportNotInitialised
        }

        // get all places
        let places = try await Database.pool.uncancellableRead { db in
            try Place.fetchAll(db)
        }

        // group places by uuid prefix
        var bucketedPlaces: [String: [Place]] = [:]
        for place in places {
            let prefix = String(place.id.prefix(1)).uppercased()
            bucketedPlaces[prefix, default: []].append(place)
        }

        // export each bucket
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        for (prefix, places) in bucketedPlaces {
            let bucketURL = placesURL.appendingPathComponent("\(prefix).json")
            let data = try encoder.encode(places)
            try data.write(to: bucketURL)
        }

        // Mark places as completed
        try finaliseMetadata(placesCompleted: true)

        // Continue with items export
        try await exportItems()
    }

    // MARK: - Items

    private static func exportItems() async throws {
        guard let itemsURL else {
            throw PersistenceError.exportNotInitialised
        }

        // Get all timeline items with their full relationships loaded
        let items = try await Database.pool.uncancellableRead { db in
            try TimelineItem
                .itemRequest(includeSamples: false, includePlaces: false)
                .order(Column("startDate").asc)  // order by date for grouping
                .fetchAll(db)
        }

        // group items by YYYY-MM
        var monthlyItems: [String: [TimelineItem]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for item in items {
            guard let startDate = item.dateRange?.start else { continue }
            let monthKey = formatter.string(from: startDate)
            monthlyItems[monthKey, default: []].append(item)
        }

        // export each month's items
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        for (monthKey, items) in monthlyItems {
            let monthURL = itemsURL.appendingPathComponent("\(monthKey).json")
            let data = try encoder.encode(items)
            try data.write(to: monthURL)
        }

        // Mark items as completed
        try finaliseMetadata(placesCompleted: true, itemsCompleted: true)

        // Continue with samples export
        try await exportSamples()
    }

    private static func exportSamples() async throws {
        guard let samplesURL else {
            throw PersistenceError.exportNotInitialised
        }

        // Get all samples ordered by date
        let samples = try await Database.pool.uncancellableRead { db in
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
            let weekId = String(format: "%4d-W%02d", year, weekOfYear)  // YYYY-Www format
            weekSamples[weekId, default: []].append(sample)
        }

        // Export each week's samples to its own file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        for (weekId, samples) in weekSamples {
            let weekURL = samplesURL.appendingPathComponent("\(weekId).json")
            let data = try encoder.encode(samples)
            try data.write(to: weekURL)
        }

        // Update metadata with success
        try finaliseMetadata(placesCompleted: true, itemsCompleted: true, samplesCompleted: true)

        // Export complete - clear state
        exportInProgress = false
    }


    // MARK: - Error handling

    private static func finaliseMetadata(placesCompleted: Bool = false, itemsCompleted: Bool = false, samplesCompleted: Bool = false) throws {
        guard let metadataURL else {
            throw PersistenceError.exportNotInitialised
        }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        // Read existing metadata
        let data = try Data(contentsOf: metadataURL)
        let metadata = try decoder.decode(ExportMetadata.self, from: data)

        // Update with completion status
        let updatedMetadata = ExportMetadata(
            schemaVersion: metadata.schemaVersion,
            exportMode: metadata.exportMode,
            exportType: metadata.exportType,
            sessionStartDate: metadata.sessionStartDate,
            sessionFinishDate: samplesCompleted ? .now : nil,  // Only set finish time if fully complete
            itemsCompleted: itemsCompleted,
            placesCompleted: placesCompleted,
            samplesCompleted: samplesCompleted,
            stats: metadata.stats
        )

        // Write updated metadata
        let updatedData = try encoder.encode(updatedMetadata)
        try updatedData.write(to: metadataURL)
    }

    private static func cleanupFailedExport() {
        // Leave completion flags as-is but ensure finish time is set
        try? finaliseMetadata()

        if let currentExportURL {
            try? FileManager.default.removeItem(at: currentExportURL)
        }
        currentExportURL = nil
        exportInProgress = false
    }
}

// MARK: -

enum PersistenceError: Error {
    // Export errors
    case exportInProgress
    case exportNotInitialised
    
    // Import errors
    case importInProgress
    case importNotInitialised
    case missingMetadata
    case missingPlacesDirectory
    case missingItemsDirectory
    case missingSamplesDirectory
    case invalidBookmark
    case securityScopeAccessDenied
    
    // iCloud errors
    case iCloudNotAvailable
    
    // Edge restoration errors
    case missingEdgeRecords
}
