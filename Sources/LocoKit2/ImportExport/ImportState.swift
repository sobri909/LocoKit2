//
//  ImportState.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-04
//

import Foundation
import GRDB

public enum ImportPhase: String, Codable, Sendable {
    case places, items, samples, extensions
}

// MARK: - Model

public struct ImportState: FetchableRecord, PersistableRecord, Codable, Sendable {

    public static let databaseTableName = "ImportState"

    public var id: Int = 1  // singleton
    public var exportId: String?
    public var startedAt: Date
    public var phase: ImportPhase
    public var processedSampleFiles: [String]?
    public var localCopyPath: String?  // path relative to app container

    public init(
        exportId: String? = nil,
        startedAt: Date = .now,
        phase: ImportPhase = .places,
        localCopyPath: String? = nil
    ) {
        self.exportId = exportId
        self.startedAt = startedAt
        self.phase = phase
        self.localCopyPath = localCopyPath
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, exportId, startedAt, phase, processedSampleFiles, localCopyPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        exportId = try container.decodeIfPresent(String.self, forKey: .exportId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        phase = try container.decode(ImportPhase.self, forKey: .phase)
        localCopyPath = try container.decodeIfPresent(String.self, forKey: .localCopyPath)

        // decode JSON array from text column
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .processedSampleFiles),
           let jsonData = jsonString.data(using: .utf8) {
            processedSampleFiles = try? JSONDecoder().decode([String].self, from: jsonData)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(exportId, forKey: .exportId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(localCopyPath, forKey: .localCopyPath)

        // encode array as JSON text
        if let files = processedSampleFiles,
           let jsonData = try? JSONEncoder().encode(files),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .processedSampleFiles)
        }
    }
}

// MARK: - Static Queries

@ImportExportActor
extension ImportState {

    /// check if there's a partial import in progress
    public static var hasPartialImport: Bool {
        get async {
            do {
                return try await Database.pool.uncancellableRead { db in
                    try ImportState.fetchOne(db) != nil
                }
            } catch {
                Log.error("hasPartialImport check failed: \(error)", subsystem: .importing)
                return false
            }
        }
    }

    /// fetch current import state if any
    public static func current() async throws -> ImportState? {
        try await Database.pool.uncancellableRead { db in
            try ImportState.fetchOne(db)
        }
    }

    /// throw if partial import is in progress (for use at entry points)
    public static func guardNotPartialImport() async throws {
        if await hasPartialImport {
            throw ImportExportError.partialImportInProgress
        }
    }

    /// create or update import state
    public static func save(_ state: ImportState) async throws {
        try await Database.pool.uncancellableWrite { db in
            try state.save(db)
        }
        Log.info("ImportState saved: phase=\(state.phase.rawValue), exportId=\(state.exportId ?? "nil")", subsystem: .importing)
    }

    /// clear import state (on completion or abandon)
    public static func clear() async throws {
        _ = try await Database.pool.uncancellableWrite { db in
            try ImportState.deleteAll(db)
        }
        Log.info("ImportState cleared", subsystem: .importing)
    }

    /// mark a sample file as processed (for resume efficiency)
    public static func markFileProcessed(_ filename: String) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try ImportState.fetchOne(db) else { return }
            var files = state.processedSampleFiles ?? []
            files.append(filename)
            state.processedSampleFiles = files
            try state.update(db)
        }
    }

    /// update the current phase
    public static func updatePhase(_ phase: ImportPhase) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try ImportState.fetchOne(db) else { return }
            state.phase = phase
            try state.update(db)
        }
        Log.info("ImportState phase updated: \(phase.rawValue)", subsystem: .importing)
    }

    /// get the local copy directory for imports
    public nonisolated static var localCopyDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportSource", isDirectory: true)
    }

    /// resolve the full URL from localCopyPath
    public static func localCopyURL(for state: ImportState) -> URL? {
        guard let path = state.localCopyPath else { return nil }
        return localCopyDirectory.appendingPathComponent(path, isDirectory: true)
    }

    /// delete any orphaned local copy (exists but no ImportState)
    public static func cleanupOrphanedCopy() async {
        let copyDir = localCopyDirectory
        guard FileManager.default.fileExists(atPath: copyDir.path) else { return }

        // if we have ImportState, copy is not orphaned
        if await hasPartialImport { return }

        // no ImportState but copy exists - it's orphaned
        do {
            try FileManager.default.removeItem(at: copyDir)
            Log.info("Deleted orphaned import copy", subsystem: .importing)
        } catch {
            Log.error(error, subsystem: .importing)
        }
    }

    /// delete the local copy directory
    public nonisolated static func deleteLocalCopy() {
        let copyDir = localCopyDirectory
        guard FileManager.default.fileExists(atPath: copyDir.path) else { return }
        do {
            try FileManager.default.removeItem(at: copyDir)
            Log.info("Deleted local import copy", subsystem: .importing)
        } catch {
            Log.error(error, subsystem: .importing)
        }
    }
}
