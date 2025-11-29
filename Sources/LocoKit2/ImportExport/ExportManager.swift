//
//  ExportManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation
import GRDB

// MARK: - Extension Protocol

public protocol ExportExtensionHandler: Sendable {
    var identifier: String { get }
    func export(to directory: URL, type: ExportType, lastBackupDate: Date?) async throws -> Int
}

// MARK: -

@ImportExportActor
public enum ExportManager {
    public static let schemaVersion = "2.0.0"

    // MARK: - Export state

    public private(set) static var exportInProgress = false
    public private(set) static var currentPhase: ExportPhase?
    public private(set) static var progress: Double = 0

    // bounded snapshot for incremental exports
    private static var currentExportType: ExportType = .full
    private static var snapshotLowerBound: Date?  // lastBackupDate from manifest (nil = export all)
    private static var snapshotUpperBound: Date?  // startTime of this export session

    public enum ExportPhase: Sendable {
        case connecting
        case exportingPlaces
        case exportingItems
        case exportingSamples
    }

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

    public static func export(
        to baseURL: URL,
        type: ExportType = .full,
        extensions: [ExportExtensionHandler] = []
    ) async throws {
        guard !exportInProgress else {
            throw ImportExportError.exportInProgress
        }

        let startTime = Date()
        exportInProgress = true
        currentPhase = .connecting
        progress = 0

        logger.info("ExportManager: Starting \(type) export", subsystem: .exporting)

        do {
            // set up export directory
            switch type {
            case .full:
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let timestamp = formatter.string(from: .now)
                let exportDir = baseURL.appendingPathComponent("export-\(timestamp)", isDirectory: true)
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                currentExportURL = exportDir

            case .incremental:
                // use baseURL directly as the backup directory
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
                currentExportURL = baseURL
            }

            // create type subdirs
            try FileManager.default.createDirectory(at: placesURL!, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: itemsURL!, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: samplesURL!, withIntermediateDirectories: true)

            // purge any iCloud conflict files before incremental export
            if type == .incremental {
                iCloudCoordinator.purgeConflictFiles(in: placesURL!)
                iCloudCoordinator.purgeConflictFiles(in: itemsURL!)
                iCloudCoordinator.purgeConflictFiles(in: samplesURL!)
            }

            // set up bounded snapshot for queries
            currentExportType = type
            snapshotUpperBound = startTime
            snapshotLowerBound = nil

            // for incremental, read existing manifest for lastBackupDate
            if type == .incremental, let existingManifest = try? loadManifest() {
                snapshotLowerBound = existingManifest.lastBackupDate
                logger.info("ExportManager: Incremental from \(snapshotLowerBound?.description ?? "beginning")", subsystem: .exporting)
            }

            // write initial metadata
            try await writeInitialMetadata(type: type, startTime: startTime)

            // sequential export phases with cancellation checks
            try Task.checkCancellation()
            try await exportPlaces()

            try Task.checkCancellation()
            try await exportItems()

            try Task.checkCancellation()
            try await exportSamples()

            // run extension handlers
            for handler in extensions {
                try Task.checkCancellation()
                let count = try await handler.export(
                    to: currentExportURL!,
                    type: type,
                    lastBackupDate: snapshotLowerBound
                )
                logger.info("ExportManager: Extension '\(handler.identifier)' exported \(count) records", subsystem: .exporting)
            }

            // finalize
            try finaliseMetadata(completed: true, startTime: startTime)
            exportInProgress = false

            let duration = Date().timeIntervalSince(startTime)
            logger.info("ExportManager: \(type) export completed in \(String(format: "%.1f", duration))s", subsystem: .exporting)

        } catch {
            logger.error("Export failed: \(error.localizedDescription)", subsystem: .exporting)
            logger.error(error, subsystem: .exporting)
            cleanupFailedExport()
            throw error
        }
    }

    // MARK: - Metadata

    private static func loadManifest() throws -> ExportMetadata? {
        guard let metadataURL, FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(ExportMetadata.self, from: data)
    }

    private static func writeInitialMetadata(type: ExportType, startTime: Date) async throws {
        guard let metadataURL else {
            throw ImportExportError.exportNotInitialised
        }

        // gather stats
        let (placeCount, itemCount, sampleCount) = try await Database.pool.uncancellableRead { db in
            let places = try Place.fetchCount(db)
            let items = try TimelineItemBase
                .filter { $0.startDate != nil }
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
            exportType: type,
            sessionStartDate: startTime,
            sessionFinishDate: nil,
            itemsCompleted: false,
            placesCompleted: false,
            samplesCompleted: false,
            stats: stats
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(metadata)
        try iCloudCoordinator.writeCoordinated(data: data, to: metadataURL)
    }

    // MARK: - Places

    private static func exportPlaces() async throws {
        guard let placesURL else {
            throw ImportExportError.exportNotInitialised
        }

        currentPhase = .exportingPlaces
        progress = 0

        logger.info("ExportManager: Starting places export", subsystem: .exporting)

        // for incremental: find which buckets have changes
        let isIncremental = currentExportType == .incremental
        let changedBuckets: Set<String>?
        if isIncremental {
            let changedPlaces = try await Database.pool.uncancellableRead { [snapshotLowerBound, snapshotUpperBound] db in
                var request = Place.all()
                if let lower = snapshotLowerBound {
                    request = request.filter { $0.lastSaved > lower }
                }
                if let upper = snapshotUpperBound {
                    request = request.filter { $0.lastSaved <= upper }
                }
                return try request.fetchAll(db)
            }
            changedBuckets = Set(changedPlaces.map { String($0.id.prefix(1)).uppercased() })
            if changedBuckets!.isEmpty {
                logger.info("ExportManager: No place changes to export", subsystem: .exporting)
                return
            }
        } else {
            changedBuckets = nil
        }

        // get all places, grouped by uuid prefix
        let places = try await Database.pool.uncancellableRead { db in
            try Place.fetchAll(db)
        }

        var bucketedPlaces: [String: [Place]] = [:]
        for place in places {
            let prefix = String(place.id.prefix(1)).uppercased()
            bucketedPlaces[prefix, default: []].append(place)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        // filter to only changed buckets for incremental
        let bucketsToWrite = isIncremental
            ? bucketedPlaces.filter { changedBuckets!.contains($0.key) }
            : bucketedPlaces

        let totalBuckets = bucketsToWrite.count
        var completedBuckets = 0

        for (prefix, bucketPlaces) in bucketsToWrite {
            try Task.checkCancellation()

            let bucketURL = placesURL.appendingPathComponent("\(prefix).json")
            let data = try encoder.encode(bucketPlaces)
            try iCloudCoordinator.writeCoordinated(data: data, to: bucketURL)

            completedBuckets += 1
            progress = Double(completedBuckets) / Double(totalBuckets)
        }

        logger.info("ExportManager: Places export completed (\(places.count) places in \(bucketedPlaces.count) buckets)", subsystem: .exporting)
    }

    // MARK: - Items

    private static func exportItems() async throws {
        guard let itemsURL else {
            throw ImportExportError.exportNotInitialised
        }

        currentPhase = .exportingItems
        progress = 0

        logger.info("ExportManager: Starting timeline items export", subsystem: .exporting)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        // for incremental: find which months have changes
        let isIncremental = currentExportType == .incremental
        let changedMonths: Set<String>?
        if isIncremental {
            let changedItems = try await Database.pool.uncancellableRead { [snapshotLowerBound, snapshotUpperBound] db in
                var request = TimelineItem
                    .itemBaseRequest(includeSamples: false, includePlaces: false)
                if let lower = snapshotLowerBound {
                    request = request.filter { $0.lastSaved > lower }
                }
                if let upper = snapshotUpperBound {
                    request = request.filter { $0.lastSaved <= upper }
                }
                return try request.asRequest(of: TimelineItem.self).fetchAll(db)
            }
            changedMonths = Set(changedItems.compactMap { item in
                guard let startDate = item.dateRange?.start else { return nil }
                return formatter.string(from: startDate)
            })
            if changedMonths!.isEmpty {
                logger.info("ExportManager: No item changes to export", subsystem: .exporting)
                return
            }
        } else {
            changedMonths = nil
        }

        // get all items, grouped by month
        let items = try await Database.pool.uncancellableRead { db in
            try TimelineItem
                .itemBaseRequest(includeSamples: false, includePlaces: false)
                .order(\.startDate.asc)
                .asRequest(of: TimelineItem.self)
                .fetchAll(db)
        }

        var monthlyItems: [String: [TimelineItem]] = [:]
        for item in items {
            guard let startDate = item.dateRange?.start else { continue }
            let monthKey = formatter.string(from: startDate)
            monthlyItems[monthKey, default: []].append(item)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        // filter to only changed months for incremental
        let monthsToWrite = isIncremental
            ? monthlyItems.filter { changedMonths!.contains($0.key) }
            : monthlyItems

        let totalMonths = monthsToWrite.count
        var completedMonths = 0

        for (monthKey, bucketItems) in monthsToWrite {
            try Task.checkCancellation()

            let monthURL = itemsURL.appendingPathComponent("\(monthKey).json")
            let data = try encoder.encode(bucketItems)
            try iCloudCoordinator.writeCoordinated(data: data, to: monthURL)

            completedMonths += 1
            progress = Double(completedMonths) / Double(totalMonths)
        }

        logger.info("ExportManager: Timeline items export completed (\(items.count) items in \(monthlyItems.count) months)", subsystem: .exporting)
    }

    // MARK: - Samples

    private static func exportSamples() async throws {
        guard let samplesURL else {
            throw ImportExportError.exportNotInitialised
        }

        currentPhase = .exportingSamples
        progress = 0

        logger.info("ExportManager: Starting samples export", subsystem: .exporting)

        let (minDate, maxDate, totalCount) = try await Database.pool.uncancellableRead { db in
            let earliest = try LocomotionSample.select({ min($0.date) }, as: Date.self).fetchOne(db)
            let latest = try LocomotionSample.select({ max($0.date) }, as: Date.self).fetchOne(db)
            let count = try LocomotionSample.fetchCount(db)
            return (earliest, latest, count)
        }

        guard let minDate, let maxDate else {
            logger.info("ExportManager: No samples to export", subsystem: .exporting)
            return
        }

        logger.info("ExportManager: Found \(totalCount) samples from \(minDate) to \(maxDate)", subsystem: .exporting)

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        var totalExported = 0
        var weekCount = 0
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: minDate)!.start
        let isIncremental = currentExportType == .incremental

        while currentWeekStart <= maxDate {
            try Task.checkCancellation()

            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!

            // for incremental: check if this week has any changes
            if isIncremental {
                let hasChanges = try await Database.pool.uncancellableRead { [currentWeekStart, weekEnd, snapshotLowerBound, snapshotUpperBound] db in
                    var request = LocomotionSample
                        .filter { $0.date >= currentWeekStart && $0.date < weekEnd }
                    if let lower = snapshotLowerBound {
                        request = request.filter { $0.lastSaved > lower }
                    }
                    if let upper = snapshotUpperBound {
                        request = request.filter { $0.lastSaved <= upper }
                    }
                    return try request.fetchCount(db) > 0
                }
                if !hasChanges {
                    currentWeekStart = weekEnd
                    continue
                }
            }

            // fetch all samples for this week
            let weekSamples = try await Database.pool.uncancellableRead { [currentWeekStart, weekEnd] db in
                try LocomotionSample
                    .filter { $0.date >= currentWeekStart && $0.date < weekEnd }
                    .order(\.date.asc)
                    .fetchAll(db)
            }

            if !weekSamples.isEmpty {
                let weekOfYear = calendar.component(.weekOfYear, from: currentWeekStart)
                let year = calendar.component(.year, from: currentWeekStart)
                let weekId = String(format: "%4d-W%02d", year, weekOfYear)

                let weekURL = samplesURL.appendingPathComponent("\(weekId).json")
                let data = try encoder.encode(weekSamples)
                try iCloudCoordinator.writeCoordinated(data: data, to: weekURL)

                totalExported += weekSamples.count
                weekCount += 1
                progress = Double(totalExported) / Double(totalCount)

                if weekCount % 10 == 0 {
                    logger.info("ExportManager: Samples progress - \(totalExported)/\(totalCount) in \(weekCount) weeks", subsystem: .exporting)
                }
            }

            currentWeekStart = weekEnd
        }

        logger.info("ExportManager: Samples export completed (\(totalExported) samples in \(weekCount) weeks)", subsystem: .exporting)
    }


    // MARK: - Metadata Finalization

    private static func finaliseMetadata(completed: Bool, startTime: Date) throws {
        guard let metadataURL else {
            throw ImportExportError.exportNotInitialised
        }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        let data = try Data(contentsOf: metadataURL)
        var metadata = try decoder.decode(ExportMetadata.self, from: data)

        if completed {
            metadata.lastBackupDate = startTime
        }

        let updatedMetadata = ExportMetadata(
            schemaVersion: metadata.schemaVersion,
            exportMode: metadata.exportMode,
            exportType: metadata.exportType,
            sessionStartDate: metadata.sessionStartDate,
            sessionFinishDate: completed ? .now : nil,
            itemsCompleted: completed,
            placesCompleted: completed,
            samplesCompleted: completed,
            stats: metadata.stats,
            lastBackupDate: metadata.lastBackupDate,
            extensions: metadata.extensions
        )

        let updatedData = try encoder.encode(updatedMetadata)
        try iCloudCoordinator.writeCoordinated(data: updatedData, to: metadataURL)
    }

    private static func cleanupFailedExport() {
        if let currentExportURL {
            try? FileManager.default.removeItem(at: currentExportURL)
        }
        currentExportURL = nil
        exportInProgress = false
    }
}

