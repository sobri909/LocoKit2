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

    /// the number of consecutive no-progress resume attempts after which the import is treated
    /// as given up (BIG-598). Erring low is safe: give-up is non-destructive (the state row
    /// persists) and Retry recovers transient failures.
    public static let maxNoProgressAttempts = 3

    public var id: Int = 1
    public var startedAt: Date
    public var phase: OldLocoKitImportPhase
    public var lastProcessedSampleRowId: Int?

    // BIG-598 escape valve: count of consecutive no-progress resume attempts (incremented at
    // the top of each attempt, reset to 0 whenever an attempt makes progress); the last failure
    // string to surface to the user; and whether the user has acknowledged the give-up state.
    public var noProgressAttemptCount: Int = 0
    public var lastError: String?
    public var acknowledged: Bool = false

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

    /// a state row exists — an import was started and hasn't fully completed/cleared, REGARDLESS
    /// of give-up. This is the row-exists meaning: it stays true through quarantine so the
    /// Settings → Backup & Restore "Import from Arc Timeline" retry affordance keeps showing, and
    /// it's what the resume-vs-fresh-start branch reads. For "should we auto-resume / defer
    /// background tasks?", use `hasActiveImport` instead.
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

    /// an incomplete import that should still auto-resume: a row exists, the last attempt did NOT
    /// throw (`lastError == nil`), AND it hasn't exhausted its no-progress attempts. The launch
    /// auto-resume trigger and BIG-600's background-task defer gate on this. A thrown failure
    /// (lastError set) OR hitting the no-progress cap stops auto-resume AND releases the BGTask gate
    /// while the row persists (quarantine) — see `hasGivenUpImport`. This is what lets an
    /// OOM/watchdog kill or an interrupted-but-progressing import keep silently resuming, while a
    /// deterministic throw surfaces the give-up cover immediately instead of looping.
    public static var hasActiveImport: Bool {
        get async {
            do {
                return try await Database.pool.uncancellableRead { db in
                    guard let state = try OldLocoKitImportState.fetchOne(db) else { return false }
                    return state.lastError == nil && state.noProgressAttemptCount < maxNoProgressAttempts
                }
            } catch {
                return false
            }
        }
    }

    /// an import that has failed and not yet been acknowledged by the user — drives the cover's
    /// error+options state. Failed means EITHER the last attempt threw (`lastError != nil` — a
    /// deterministic failure, surfaced immediately including on the first attempt) OR it hit the
    /// no-progress attempt cap (the OOM/watchdog-kill path, which can't surface a cover in-session
    /// so it retries up to the cap first). Once acknowledged, the row persists (for a post-fix
    /// retry) but this returns false so the app proceeds to normal launch.
    public static var hasGivenUpImport: Bool {
        get async {
            do {
                return try await Database.pool.uncancellableRead { db in
                    guard let state = try OldLocoKitImportState.fetchOne(db) else { return false }
                    return !state.acknowledged
                        && (state.lastError != nil || state.noProgressAttemptCount >= maxNoProgressAttempts)
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

    /// update last processed sample rowid (for resume within samples phase). A rowid advance is
    /// the BIG-598 forward-progress signal: it resets the no-progress attempt counter, so a
    /// legitimate slow multi-launch import (rowid climbing each launch) never trips the give-up
    /// cap. Phase transitions are NOT used as a progress signal — performImportPhases re-runs the
    /// idempotent Places/Items phases on every resume, so updatePhase fires redundantly.
    public static func updateLastProcessedSampleRowId(_ rowId: Int) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            if rowId > (state.lastProcessedSampleRowId ?? Int.min) {
                state.noProgressAttemptCount = 0
            }
            state.lastProcessedSampleRowId = rowId
            try state.update(db)
        }
    }

    /// increment the no-progress attempt counter at the START of an import attempt, committed
    /// before the heavy work — so an OOM/watchdog kill (which never runs a catch) is still counted
    /// on the next launch (BIG-598: count attempts started, not just throws). Reset to 0 by
    /// `updateLastProcessedSampleRowId` when an attempt makes forward progress. Also clears
    /// `lastError` so it reflects only THIS attempt's outcome (set in the catch iff this attempt
    /// throws) — `hasGivenUpImport` reads it to surface a thrown failure immediately. Logs the
    /// attempt number so a stuck user's log file shows how many attempts there have been.
    public static func recordAttemptStart() async throws {
        let attempt = try await Database.pool.uncancellableWrite { db -> Int in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return 0 }
            state.noProgressAttemptCount += 1
            state.lastError = nil
            try state.update(db)
            return state.noProgressAttemptCount
        }
        if attempt > 0 {
            Log.info("OldLocoKit import: attempt \(attempt)", subsystem: .importing)
        }
    }

    /// record the failure to surface to the user on give-up (BIG-598). Best-effort. Stores
    /// `String(describing:)` (the case name for our `ImportExportError`, e.g. "invalidDatabaseSchema",
    /// or a descriptive string for GRDB/system errors) rather than `localizedDescription`, which for
    /// a plain enum yields the useless "…error 16" — support can't decode an auto-assigned ordinal.
    public static func recordError(_ error: Error) async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            state.lastError = String(describing: error)
            try state.update(db)
        }
    }

    /// mark the give-up state as acknowledged (user tapped "Continue for Now"): the cover stops
    /// blocking each launch, but the row persists so a post-fix retry still works. (BIG-598)
    public static func markAcknowledged() async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            state.acknowledged = true
            try state.update(db)
        }
    }

    /// re-arm a given-up import for another run (user tapped "Try Again"): clear the no-progress
    /// count, the last error, and the acknowledged flag so it auto-resumes cleanly again. (BIG-598)
    public static func resetForRetry() async throws {
        try await Database.pool.uncancellableWrite { db in
            guard var state = try OldLocoKitImportState.fetchOne(db) else { return }
            state.noProgressAttemptCount = 0
            state.lastError = nil
            state.acknowledged = false
            try state.update(db)
        }
    }
}
