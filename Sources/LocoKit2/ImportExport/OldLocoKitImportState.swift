//
//  OldLocoKitImportState.swift
//  LocoKit2
//
//  Created by Claude on 2026-02-16
//

import Foundation
import GRDB

public enum OldLocoKitImportPhase: String, Codable, Sendable {
    case places, items, samples
}

// MARK: - Model

public struct OldLocoKitImportState: FetchableRecord, PersistableRecord, Codable, Sendable {

    public static let databaseTableName = "OldLocoKitImportState"

    public var id: Int = 1
    public var startedAt: Date
    public var phase: OldLocoKitImportPhase
    public var lastProcessedSampleRowId: Int?

    public init(
        startedAt: Date = .now,
        phase: OldLocoKitImportPhase = .places
    ) {
        self.startedAt = startedAt
        self.phase = phase
    }
}

// MARK: - Static Queries

@ImportExportActor
extension OldLocoKitImportState {

    /// check if there's an incomplete old LocoKit import
    public static var hasIncompleteImport: Bool {
        get async {
            do {
                return try await Database.pool.uncancellableRead { db in
                    try OldLocoKitImportState.fetchOne(db) != nil
                }
            } catch {
                return false
            }
        }
    }

    /// fetch current import state if any
    public static func current() async throws -> OldLocoKitImportState? {
        try await Database.pool.uncancellableRead { db in
            try OldLocoKitImportState.fetchOne(db)
        }
    }

    /// create or update import state
    public static func save(_ state: OldLocoKitImportState) async throws {
        try await Database.pool.uncancellableWrite { db in
            try state.save(db)
        }
        Log.info("OldLocoKitImportState saved: phase=\(state.phase.rawValue)", subsystem: .importing)
    }

    /// clear import state (on completion or abandon)
    public static func clear() async throws {
        _ = try await Database.pool.uncancellableWrite { db in
            try OldLocoKitImportState.deleteAll(db)
        }
        Log.info("OldLocoKitImportState cleared", subsystem: .importing)
    }

    /// update the current phase
    public static func updatePhase(_ phase: OldLocoKitImportPhase) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            state.phase = phase
            try state.update(db)
        }
        Log.info("OldLocoKitImportState phase: \(phase.rawValue)", subsystem: .importing)
    }

    /// update last processed sample rowid (for resume within samples phase)
    public static func updateLastProcessedSampleRowId(_ rowId: Int) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            state.lastProcessedSampleRowId = rowId
            try state.update(db)
        }
    }
}
