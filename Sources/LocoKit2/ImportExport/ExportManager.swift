//
//  ExportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation
import GRDB

@ImportExportActor
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
            throw ImportExportError.exportInProgress
        }

        let startTime = Date()
        exportInProgress = true
        
        logger.info("ExportManager: Starting JSON export", subsystem: .exporting)

        // create root export dir with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: .now)

        // Get iCloud container root
        guard let iCloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            cleanupFailedExport()
            throw ImportExportError.iCloudNotAvailable
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
            
            // Export completed successfully
            let duration = Date().timeIntervalSince(startTime)
            let durationString = String(format: "%.1f", duration)
            let (placeCount, itemCount, sampleCount) = try await Database.pool.uncancellableRead { db in
                let places = try Place.fetchCount(db)
                let items = try TimelineItemBase
                    .filter(Column("startDate") != nil)
                    .fetchCount(db)
                let samples = try LocomotionSample.fetchCount(db)
                return (places, items, samples)
            }
            logger.info("ExportManager completed successfully in \(durationString)s: \(placeCount) places, \(itemCount) items, \(sampleCount) samples", subsystem: .exporting)
            
        } catch {
            logger.error("Export failed: \(error.localizedDescription)", subsystem: .exporting)
            logger.error(error, subsystem: .exporting)
            cleanupFailedExport()
            throw error
        }
    }

    // MARK: - Metadata

    private static func writeInitialMetadata() async throws {
        guard let metadataURL else {
            throw ImportExportError.exportNotInitialised
        }

        // Gather stats
        let (placeCount, itemCount, sampleCount) = try await Database.pool.uncancellableRead { db in
            let places = try Place.fetchCount(db)
            let items = try TimelineItemBase
                .filter(Column("startDate") != nil)
                .fetchCount(db)
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
            throw ImportExportError.exportNotInitialised
        }
        
        logger.info("ExportManager: Starting places export", subsystem: .exporting)

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
            print("Exported \(places.count) places to \(prefix).json")
        }
        
        logger.info("ExportManager: Places export completed (\(places.count) places in \(bucketedPlaces.count) buckets)", subsystem: .exporting)

        // Mark places as completed
        try finaliseMetadata(placesCompleted: true)

        // Continue with items export
        try await exportItems()
    }

    // MARK: - Items

    private static func exportItems() async throws {
        guard let itemsURL else {
            throw ImportExportError.exportNotInitialised
        }
        
        logger.info("ExportManager: Starting timeline items export", subsystem: .exporting)

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
            print("Exported \(items.count) items to \(monthKey).json")
        }
        
        logger.info("ExportManager: Timeline items export completed (\(items.count) items in \(monthlyItems.count) months)", subsystem: .exporting)

        // Mark items as completed
        try finaliseMetadata(placesCompleted: true, itemsCompleted: true)

        // Continue with samples export
        try await exportSamples()
    }

    // MARK: - Samples
    
    private static func exportSamples() async throws {
        guard let samplesURL else {
            throw ImportExportError.exportNotInitialised
        }
        
        logger.info("ExportManager: Starting samples export", subsystem: .exporting)

        // First get the date range of samples to export
        let (minDate, maxDate, totalCount) = try await Database.pool.uncancellableRead { db in
            let min = try Date.fetchOne(db, LocomotionSample.select(min(Column("date"))))
            let max = try Date.fetchOne(db, LocomotionSample.select(max(Column("date"))))
            let count = try LocomotionSample.fetchCount(db)
            return (min, max, count)
        }
        
        guard let minDate, let maxDate else {
            logger.info("ExportManager: No samples to export", subsystem: .exporting)
            // Update metadata with success (but no samples)
            try finaliseMetadata(placesCompleted: true, itemsCompleted: true, samplesCompleted: true)
            exportInProgress = false
            return
        }
        
        logger.info("ExportManager: Found \(totalCount) samples from \(minDate) to \(maxDate)", subsystem: .exporting)

        // Set up UTC calendar for consistent week calculations
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2  // Monday = 2
        
        // Process samples week by week to avoid memory pressure
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        var totalExported = 0
        var weekCount = 0
        
        // Start from the beginning of the week containing minDate
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: minDate)!.start
        
        while currentWeekStart <= maxDate {
            // Calculate week end
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
            
            // Query only this week's samples
            let weekSamples = try await Database.pool.uncancellableRead { [currentWeekStart, weekEnd] db in
                try LocomotionSample
                    .filter(Column("date") >= currentWeekStart && Column("date") < weekEnd)
                    .order(Column("date").asc)
                    .fetchAll(db)
            }
            
            if !weekSamples.isEmpty {
                // Generate week ID in YYYY-Www format
                let weekOfYear = calendar.component(.weekOfYear, from: currentWeekStart)
                let year = calendar.component(.year, from: currentWeekStart)
                let weekId = String(format: "%4d-W%02d", year, weekOfYear)
                
                // Write this week's samples
                let weekURL = samplesURL.appendingPathComponent("\(weekId).json")
                let data = try encoder.encode(weekSamples)
                try data.write(to: weekURL)
                
                totalExported += weekSamples.count
                weekCount += 1
                
                print("Exported \(weekSamples.count) samples to \(weekId).json")
                
                // Log progress every 10 weeks
                if weekCount % 10 == 0 {
                    logger.info("ExportManager: Samples export progress - \(totalExported)/\(totalCount) samples in \(weekCount) weeks", subsystem: .exporting)
                }
            }
            
            // Move to next week
            currentWeekStart = weekEnd
        }
        
        logger.info("ExportManager: Samples export completed (\(totalExported) samples in \(weekCount) weeks)", subsystem: .exporting)

        // Update metadata with success
        try finaliseMetadata(placesCompleted: true, itemsCompleted: true, samplesCompleted: true)

        // Export complete - clear state
        exportInProgress = false
    }


    // MARK: - Error handling

    private static func finaliseMetadata(placesCompleted: Bool = false, itemsCompleted: Bool = false, samplesCompleted: Bool = false) throws {
        guard let metadataURL else {
            throw ImportExportError.exportNotInitialised
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

