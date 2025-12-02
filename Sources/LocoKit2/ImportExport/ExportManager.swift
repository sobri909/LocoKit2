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
    public static let schemaVersion = "2.1.0"

    // MARK: - Export state

    public private(set) static var exportInProgress = false
    public private(set) static var currentPhase: ExportPhase?
    public private(set) static var progress: Double = 0

    // bounded snapshot for incremental exports
    private static var currentExportType: ExportType = .full
    private static var snapshotLowerBound: Date?  // lastBackupDate from manifest (nil = export all)
    private static var snapshotUpperBound: Date?  // startTime of this export session

    // catch-up mode for first-run chunked backups
    private static var catchUpDateRange: DateInterval?  // nil = normal mode, set = catch-up chunk
    private static let catchUpChunkSize: TimeInterval = .months(6)

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
            try setupExportDirectory(type: type, baseURL: baseURL)
            currentExportType = type
            snapshotUpperBound = startTime
            snapshotLowerBound = nil
            catchUpDateRange = nil

            await determineIncrementalMode(type: type, startTime: startTime)

            // write initial metadata
            try await writeInitialMetadata(type: type, startTime: startTime)

            // sequential export phases with cancellation checks
            try Task.checkCancellation()
            try await exportPlaces()

            try Task.checkCancellation()
            try await exportItems()

            try await exportSamplesWithCatchUp(startTime: startTime)

            // run extension handlers
            var extensionStates: [String: ExtensionState] = [:]
            for handler in extensions {
                try Task.checkCancellation()
                let count = try await handler.export(
                    to: currentExportURL!,
                    type: type,
                    lastBackupDate: snapshotLowerBound
                )
                extensionStates[handler.identifier] = ExtensionState(recordCount: count)
                logger.info("ExportManager: Extension '\(handler.identifier)' exported \(count) records", subsystem: .exporting)
            }

            // finalize
            try finaliseMetadata(
                placesCompleted: true,
                itemsCompleted: true,
                samplesCompleted: true,
                startTime: startTime,
                extensions: extensionStates
            )
            exportInProgress = false

            logger.info("ExportManager: \(type) export completed in \(String(format: "%.1f", startTime.age))s", subsystem: .exporting)

        } catch {
            logger.error("Export failed: \(error.localizedDescription)", subsystem: .exporting)
            logger.error(error, subsystem: .exporting)
            cleanupFailedExport()
            throw error
        }
    }

    // MARK: - Setup

    private static func determineIncrementalMode(type: ExportType, startTime: Date) async {
        guard type == .incremental else { return }

        if let existingManifest = try? loadManifest() {
            if let lastBackup = existingManifest.lastBackupDate {
                // normal incremental: export changes since last backup
                snapshotLowerBound = lastBackup
                logger.info("ExportManager: Incremental from \(lastBackup)", subsystem: .exporting)

            } else {
                // catch-up mode: resuming incomplete first backup
                let progressDate = existingManifest.backupProgressDate
                let earliestDate = await getEarliestDataDate()
                let chunkStart = progressDate ?? earliestDate ?? startTime
                let chunkEnd = min(chunkStart.addingTimeInterval(catchUpChunkSize), startTime)
                catchUpDateRange = DateInterval(start: chunkStart, end: chunkEnd)
                logger.info("ExportManager: Catch-up mode from \(chunkStart) to \(chunkEnd)", subsystem: .exporting)
            }

        } else {
            // no manifest: first backup, start catch-up from earliest data
            let earliestDate = await getEarliestDataDate()
            let chunkStart = earliestDate ?? startTime
            let chunkEnd = min(chunkStart.addingTimeInterval(catchUpChunkSize), startTime)
            catchUpDateRange = DateInterval(start: chunkStart, end: chunkEnd)
            logger.info("ExportManager: Catch-up mode (first run) from \(chunkStart) to \(chunkEnd)", subsystem: .exporting)
        }
    }

    private static func exportBucketed<T: Encodable & Sendable>(
        phase: ExportPhase,
        directory: URL,
        entityName: String,
        fetchChangedKeys: () async throws -> Set<String>,
        fetchAll: () async throws -> [T],
        bucketKey: (T) -> String?
    ) async throws {
        currentPhase = phase
        progress = 0

        logger.info("ExportManager: Starting \(entityName) export", subsystem: .exporting)

        // for incremental: find which buckets have changes
        let isIncremental = currentExportType == .incremental
        let changedKeys: Set<String>?

        if isIncremental {
            changedKeys = try await fetchChangedKeys()
            if changedKeys!.isEmpty {
                logger.info("ExportManager: No \(entityName) changes to export", subsystem: .exporting)
                return
            }
        } else {
            changedKeys = nil
        }

        // fetch all and group by bucket key
        let allItems = try await fetchAll()

        var bucketed: [String: [T]] = [:]
        for item in allItems {
            guard let key = bucketKey(item) else { continue }
            bucketed[key, default: []].append(item)
        }

        // filter to only changed buckets for incremental
        let bucketsToWrite = isIncremental
            ? bucketed.filter { changedKeys!.contains($0.key) }
            : bucketed

        let encoder = JSONEncoder.iso8601Encoder()

        let totalBuckets = bucketsToWrite.count
        var completedBuckets = 0

        for (key, items) in bucketsToWrite {
            try Task.checkCancellation()

            let bucketURL = directory.appendingPathComponent("\(key).json")
            let data = try encoder.encode(items)
            try iCloudCoordinator.writeCoordinated(data: data, to: bucketURL)

            completedBuckets += 1
            progress = (Double(completedBuckets) / Double(totalBuckets)).clamped(min: 0, max: 1)
        }

        logger.info("ExportManager: \(entityName) export completed (\(allItems.count) in \(bucketed.count) buckets)", subsystem: .exporting)
    }

    private static func setupExportDirectory(type: ExportType, baseURL: URL) throws {
        switch type {
        case .full:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let timestamp = formatter.string(from: .now)
            let exportDir = baseURL.appendingPathComponent("export-\(timestamp)", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            currentExportURL = exportDir

        case .incremental:
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            currentExportURL = baseURL
        }

        // create subdirectories
        try FileManager.default.createDirectory(at: placesURL!, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: itemsURL!, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: samplesURL!, withIntermediateDirectories: true)

        // purge iCloud conflict files for incremental
        if type == .incremental {
            iCloudCoordinator.purgeConflictFiles(in: placesURL!)
            iCloudCoordinator.purgeConflictFiles(in: itemsURL!)
            iCloudCoordinator.purgeConflictFiles(in: samplesURL!)
        }
    }

    // MARK: - Metadata

    private static func loadManifest() throws -> ExportMetadata? {
        guard let metadataURL, FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder.flexibleDateDecoder().decode(ExportMetadata.self, from: data)
    }

    private static func getEarliestDataDate() async -> Date? {
        try? await Database.pool.read { db in
            try LocomotionSample.select({ min($0.date) }, as: Date.self).fetchOne(db)
        }
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

        let encoder = JSONEncoder.iso8601Encoder()
        let data = try encoder.encode(metadata)
        try iCloudCoordinator.writeCoordinated(data: data, to: metadataURL)
    }

    // MARK: - Places

    private static func exportPlaces() async throws {
        guard let placesURL else {
            throw ImportExportError.exportNotInitialised
        }

        try await exportBucketed(
            phase: .exportingPlaces,
            directory: placesURL,
            entityName: "places",
            fetchChangedKeys: {
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
                return Set(changedPlaces.map { String($0.id.prefix(1)).uppercased() })
            },
            fetchAll: {
                try await Database.pool.uncancellableRead { db in
                    try Place.fetchAll(db)
                }
            },
            bucketKey: { place in
                String(place.id.prefix(1)).uppercased()
            }
        )
    }

    // MARK: - Items

    private static func exportItems() async throws {
        guard let itemsURL else {
            throw ImportExportError.exportNotInitialised
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        try await exportBucketed(
            phase: .exportingItems,
            directory: itemsURL,
            entityName: "timeline items",
            fetchChangedKeys: {
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
                return Set(changedItems.compactMap { item in
                    guard let startDate = item.dateRange?.start else { return nil }
                    return formatter.string(from: startDate)
                })
            },
            fetchAll: {
                try await Database.pool.uncancellableRead { db in
                    try TimelineItem
                        .itemBaseRequest(includeSamples: false, includePlaces: false)
                        .order(\.startDate.asc)
                        .asRequest(of: TimelineItem.self)
                        .fetchAll(db)
                }
            },
            bucketKey: { item in
                guard let startDate = item.dateRange?.start else { return nil }
                return formatter.string(from: startDate)
            }
        )
    }

    // MARK: - Samples

    private static func exportSamplesWithCatchUp(startTime: Date) async throws {
        if catchUpDateRange != nil {
            // catch-up mode: loop through chunks until complete
            while catchUpDateRange != nil {
                try Task.checkCancellation()
                try await exportSamples()

                try finaliseMetadata(
                    placesCompleted: true,
                    itemsCompleted: true,
                    samplesCompleted: false,
                    startTime: startTime
                )

                // check if caught up, calculate next chunk if not
                if let manifest = try? loadManifest() {
                    if manifest.lastBackupDate != nil {
                        catchUpDateRange = nil
                    } else if let progressDate = manifest.backupProgressDate {
                        let nextEnd = min(progressDate.addingTimeInterval(catchUpChunkSize), startTime)
                        catchUpDateRange = DateInterval(start: progressDate, end: nextEnd)
                    }
                }
            }

        } else {
            // normal mode: single export pass
            try Task.checkCancellation()
            try await exportSamples()
        }
    }

    private static func exportSamples() async throws {
        guard let samplesURL else {
            throw ImportExportError.exportNotInitialised
        }

        currentPhase = .exportingSamples
        progress = 0

        logger.info("ExportManager: Starting samples export", subsystem: .exporting)

        // determine date range to export
        let exportStart: Date
        let exportEnd: Date
        let totalCount: Int

        if let catchUpRange = catchUpDateRange {
            // catch-up mode: export specific date range
            exportStart = catchUpRange.start
            exportEnd = catchUpRange.end
            totalCount = try await Database.pool.uncancellableRead { [exportStart, exportEnd] db in
                try LocomotionSample
                    .filter { $0.date >= exportStart && $0.date < exportEnd }
                    .fetchCount(db)
            }
            logger.info("ExportManager: Catch-up chunk with \(totalCount) samples from \(exportStart) to \(exportEnd)", subsystem: .exporting)

        } else {
            // full or normal incremental: use full data range
            let (minDate, maxDate, count) = try await Database.pool.uncancellableRead { db in
                let earliest = try LocomotionSample.select({ min($0.date) }, as: Date.self).fetchOne(db)
                let latest = try LocomotionSample.select({ max($0.date) }, as: Date.self).fetchOne(db)
                let count = try LocomotionSample.fetchCount(db)
                return (earliest, latest, count)
            }

            guard let minDate, let maxDate else {
                logger.info("ExportManager: No samples to export", subsystem: .exporting)
                return
            }

            exportStart = minDate
            exportEnd = maxDate
            totalCount = count
            logger.info("ExportManager: Found \(totalCount) samples from \(exportStart) to \(exportEnd)", subsystem: .exporting)
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2

        let encoder = JSONEncoder.iso8601Encoder()

        var totalExported = 0
        var weekCount = 0
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: exportStart)!.start
        let isNormalIncremental = currentExportType == .incremental && catchUpDateRange == nil

        while currentWeekStart <= exportEnd {
            try Task.checkCancellation()

            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!

            // for normal incremental (not catch-up): check if this week has any changes
            if isNormalIncremental {
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
                progress = (Double(totalExported) / Double(totalCount)).clamped(min: 0, max: 1)

                if weekCount % 10 == 0 {
                    logger.info("ExportManager: Samples progress - \(totalExported)/\(totalCount) in \(weekCount) weeks", subsystem: .exporting)
                }
            }

            currentWeekStart = weekEnd
        }

        logger.info("ExportManager: Samples export completed (\(totalExported) samples in \(weekCount) weeks)", subsystem: .exporting)
    }


    // MARK: - Metadata Finalization

    private static func finaliseMetadata(
        placesCompleted: Bool,
        itemsCompleted: Bool,
        samplesCompleted: Bool,
        startTime: Date,
        extensions: [String: ExtensionState] = [:]
    ) throws {
        guard let metadataURL else {
            throw ImportExportError.exportNotInitialised
        }

        let decoder = JSONDecoder.flexibleDateDecoder()
        let encoder = JSONEncoder.iso8601Encoder()

        let data = try Data(contentsOf: metadataURL)
        let metadata = try decoder.decode(ExportMetadata.self, from: data)

        // handle catch-up mode vs normal mode
        var newBackupProgressDate = metadata.backupProgressDate
        var newLastBackupDate = metadata.lastBackupDate

        if let catchUpRange = catchUpDateRange {
            // catch-up mode: update progress
            newBackupProgressDate = catchUpRange.end

            // check if we're caught up (chunk end reached present time)
            if catchUpRange.end >= startTime {
                newLastBackupDate = startTime
                newBackupProgressDate = nil  // clear progress, we're done catching up
                logger.info("ExportManager: Catch-up complete, switching to normal incremental mode", subsystem: .exporting)
            }

        } else if samplesCompleted {
            // normal mode: update lastBackupDate when samples are done
            newLastBackupDate = startTime
        }

        // merge new extension states with existing
        var mergedExtensions = metadata.extensions ?? [:]
        for (key, value) in extensions {
            mergedExtensions[key] = value
        }

        let allCompleted = placesCompleted && itemsCompleted && samplesCompleted

        let updatedMetadata = ExportMetadata(
            schemaVersion: metadata.schemaVersion,
            exportMode: metadata.exportMode,
            exportType: metadata.exportType,
            sessionStartDate: metadata.sessionStartDate,
            sessionFinishDate: allCompleted ? .now : nil,
            itemsCompleted: itemsCompleted,
            placesCompleted: placesCompleted,
            samplesCompleted: samplesCompleted,
            stats: metadata.stats,
            lastBackupDate: newLastBackupDate,
            backupProgressDate: newBackupProgressDate,
            extensions: mergedExtensions.isEmpty ? nil : mergedExtensions
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

