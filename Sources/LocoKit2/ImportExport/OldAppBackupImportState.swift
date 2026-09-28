//
//  OldAppBackupImportState.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation
import GRDB

// MARK: - Model

/// Resume state for an old-app backup-set import (BIG-399). Its own singleton table, never the
/// JSON restore's `ImportState`, so an interrupted backup-set import cannot collide with an
/// interrupted JSON restore and the two covers never have to tell each other apart.
///
/// The checkpoint is the list of sample-week stems already processed: each week is one
/// transaction, so a resume re-runs the current week idempotently (insert-or-ignore) and skips
/// the rest. The source folder is kept as a security-scoped bookmark so a resume after a
/// relaunch can reopen the user's picked folder without asking again.
public struct OldAppBackupImportState: FetchableRecord, PersistableRecord, Codable, Sendable {

    public static let databaseTableName = "OldAppBackupImportState"

    /// consecutive no-progress attempts before the import is treated as given up (BIG-598 shape).
    /// Progress = a week marked processed. Give-up is non-destructive: the row persists for retry.
    public static let maxNoProgressAttempts = 3

    public var id: Int = 1
    public var startedAt: Date
    public var sourceBookmark: Data
    public var processedWeekStems: [String] = []
    public var totalWeekCount: Int = 0
    /// only records dated before this import (Migrate's parallel-era window: the earliest data
    /// AT4 itself recorded); nil imports everything. Fixed at start so a resume applies the same cut.
    public var cutoffDate: Date?

    public var noProgressAttemptCount: Int = 0
    public var lastError: String?
    public var acknowledged: Bool = false

    public init(startedAt: Date = .now, sourceBookmark: Data, totalWeekCount: Int, cutoffDate: Date?) {
        self.startedAt = startedAt
        self.sourceBookmark = sourceBookmark
        self.totalWeekCount = totalWeekCount
        self.cutoffDate = cutoffDate
    }

    // `processedWeekStems` is stored as a JSON text column
    enum CodingKeys: String, CodingKey {
        case id, startedAt, sourceBookmark, processedWeekStems, totalWeekCount, cutoffDate, noProgressAttemptCount, lastError, acknowledged
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        sourceBookmark = try c.decode(Data.self, forKey: .sourceBookmark)
        totalWeekCount = try c.decode(Int.self, forKey: .totalWeekCount)
        cutoffDate = try c.decodeIfPresent(Date.self, forKey: .cutoffDate)
        noProgressAttemptCount = try c.decode(Int.self, forKey: .noProgressAttemptCount)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        acknowledged = try c.decode(Bool.self, forKey: .acknowledged)
        let stemsJSON = try c.decodeIfPresent(String.self, forKey: .processedWeekStems) ?? "[]"
        processedWeekStems = (try? JSONDecoder().decode([String].self, from: Data(stemsJSON.utf8))) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(sourceBookmark, forKey: .sourceBookmark)
        try c.encode(totalWeekCount, forKey: .totalWeekCount)
        try c.encodeIfPresent(cutoffDate, forKey: .cutoffDate)
        try c.encode(noProgressAttemptCount, forKey: .noProgressAttemptCount)
        try c.encodeIfPresent(lastError, forKey: .lastError)
        try c.encode(acknowledged, forKey: .acknowledged)
        let stemsJSON = String(decoding: try JSONEncoder().encode(processedWeekStems), as: UTF8.self)
        try c.encode(stemsJSON, forKey: .processedWeekStems)
    }

    public var progress: Double {
        guard totalWeekCount > 0 else { return 0 }
        return Double(processedWeekStems.count) / Double(totalWeekCount)
    }
}

// MARK: - Static Queries

@ImportExportActor
extension OldAppBackupImportState {

    /// a state row exists: an import was started and hasn't completed or been abandoned,
    /// regardless of give-up. Drives the Settings retry affordance and the resume-vs-fresh branch.
    public static var hasIncompleteImport: Bool {
        get async {
            (try? await Database.pool.uncancellableRead { db in
                try OldAppBackupImportState.fetchOne(db) != nil
            }) ?? false
        }
    }

    /// an incomplete import that should still auto-resume: a row exists, the last attempt did
    /// not throw, and the no-progress cap hasn't been hit.
    public static var hasActiveImport: Bool {
        get async {
            (try? await Database.pool.uncancellableRead { db in
                guard let state = try OldAppBackupImportState.fetchOne(db) else { return false }
                return state.lastError == nil && state.noProgressAttemptCount < maxNoProgressAttempts
            }) ?? false
        }
    }

    /// failed (threw, or hit the no-progress cap) and not yet acknowledged: drives the give-up cover.
    public static var hasGivenUpImport: Bool {
        get async {
            (try? await Database.pool.uncancellableRead { db in
                guard let state = try OldAppBackupImportState.fetchOne(db) else { return false }
                return !state.acknowledged
                    && (state.lastError != nil || state.noProgressAttemptCount >= maxNoProgressAttempts)
            }) ?? false
        }
    }

    public static func current() async throws -> OldAppBackupImportState? {
        try await Database.pool.uncancellableRead { db in
            try OldAppBackupImportState.fetchOne(db)
        }
    }

    public static func save(_ state: OldAppBackupImportState) async throws {
        try await Database.pool.uncancellableWrite { db in
            try state.save(db)
        }
        Log.info("OldAppBackupImportState saved: \(state.processedWeekStems.count)/\(state.totalWeekCount) weeks", subsystem: .importing)
    }

    public static func clear() async throws {
        _ = try await Database.pool.uncancellableWrite { db in
            try OldAppBackupImportState.deleteAll(db)
        }
        Log.info("OldAppBackupImportState cleared", subsystem: .importing)
    }

    /// a week landed: the forward-progress signal, which also resets the no-progress counter
    public static func markWeekProcessed(_ stem: String) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldAppBackupImportState.fetchOne(db) else { return }
            if !state.processedWeekStems.contains(stem) {
                state.processedWeekStems.append(stem)
            }
            state.noProgressAttemptCount = 0
            try state.update(db)
        }
    }

    /// counted at the START of an attempt, committed before the heavy work, so an OOM or
    /// watchdog kill (which never runs a catch) is still counted at the next launch (BIG-598)
    public static func recordAttemptStart() async throws {
        let attempt = try await Database.pool.uncancellableWrite { db -> Int in
            guard var state = try OldAppBackupImportState.fetchOne(db) else { return 0 }
            state.noProgressAttemptCount += 1
            state.lastError = nil
            try state.update(db)
            return state.noProgressAttemptCount
        }
        if attempt > 0 {
            Log.info("OldAppBackup import: attempt \(attempt)", subsystem: .importing)
        }
    }

    public static func recordError(_ error: Error) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldAppBackupImportState.fetchOne(db) else { return }
            state.lastError = String(describing: error)
            try state.update(db)
        }
    }

    public static func markAcknowledged() async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldAppBackupImportState.fetchOne(db) else { return }
            state.acknowledged = true
            try state.update(db)
        }
    }

    public static func resetForRetry() async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldAppBackupImportState.fetchOne(db) else { return }
            state.noProgressAttemptCount = 0
            state.lastError = nil
            state.acknowledged = false
            try state.update(db)
        }
    }
}
