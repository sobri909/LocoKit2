//
//  StorageHealthMonitor.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-21
//

import Foundation
import GRDB
import Synchronization

/// BIG-745: catches out-of-space write failures at the one point that sees them all.
///
/// Every edit path calls `DatabasePool.write` directly and swallows its error into a log line,
/// so there is no per-path choke point. GRDB's `Database.logError` is SQLite's own
/// `sqlite3_config(SQLITE_CONFIG_LOG)` callback: process-wide, every connection (Sentry's store
/// and the legacy pool included), every error. This monitor ACTS on the out-of-space class only,
/// logs storage-failing I/O errors, and ignores everything else — BUSY/LOCKED/CONSTRAINT/NOTICE,
/// CORRUPT and the rest already surface through their throwing call sites. It must be installed
/// before the FIRST SQLite connection opens anywhere in the process — for Arc that means the first
/// line of `ArcTimelineEditorApp.init()`, above `SentrySDK.start` (Sentry opens its own store).
///
/// The callback also fires for benign notices on every cold launch (`SQLITE_NOTICE_RECOVER_WAL`,
/// code 283), so it filters on the result code and never on presence.
public enum StorageHealthMonitor {

    /// Call as the first line of the app's init, before anything opens a database.
    public static func installErrorHook() {
        GRDB.Database.logError = { resultCode, message in
            handle(resultCode: resultCode, message: message)
        }
    }

    /// Called by `Database` when it creates the main pool: a commit there that changed rows is
    /// the ground truth that writes work again. (The raise side is process-wide; the clear side
    /// is deliberately the main pool only — nothing else in the process writes on a cadence.)
    static func observeCommits(on pool: DatabasePool) {
        pool.add(transactionObserver: commitObserver, extent: .observerLifetime)
    }

    // MARK: - Error classification

    /// Runs on SQLite's thread, inside a SQLite call: must not touch any database and must
    /// return quickly. Out-of-space raises the banner; storage-*failing* I/O errors get an
    /// error-tier log line and no banner (telling a user their phone is dying when it is
    /// merely full, or vice versa, is worse than the log line alone).
    private static func handle(resultCode: ResultCode, message: String) {
        let now = Date()  // the event's time, not the time the main-actor hop lands
        if isOutOfSpace(resultCode) {
            let description = "\(resultCode.rawValue): \(message)"
            Task { @MainActor in
                StorageHealth.highlander.recordFailure(description, at: now)
            }
        } else if resultCode.primaryResultCode == .SQLITE_IOERR {
            // a failing disk emits these in bursts, and this runs inside the SQLite call:
            // one line per 10 s is diagnosis enough
            let shouldLog = lastIOErrorLog.withLock { last in
                if let last, now.timeIntervalSince(last) < 10 { return false }
                last = now
                return true
            }
            if shouldLog {
                Log.error("SQLite I/O error \(resultCode.rawValue): \(message)", subsystem: .database)
            }
        }
    }

    private static let lastIOErrorLog = Mutex<Date?>(nil)

    /// `SQLITE_FULL` (13) is the volume-full code. `SQLITE_IOERR_SHMSIZE` (4874) is the WAL-mode
    /// path for the same condition: sqlite.org — "may indicate that the underlying filesystem
    /// volume is out of space". Nothing else in the IOERR family means out-of-space.
    static func isOutOfSpace(_ code: ResultCode) -> Bool {
        return code.primaryResultCode == .SQLITE_FULL || code == .SQLITE_IOERR_SHMSIZE
    }

    // MARK: - Commit observation

    /// Mirror of `StorageHealth.storageFull`, readable off the writer queue so the commit
    /// observer only hops to the main actor while the banner is actually up.
    private static let bannerUp = Mutex(false)

    static func setBannerUp(_ up: Bool) {
        bannerUp.withLock { $0 = up }
    }

    private static let commitObserver = CommitObserver()

    /// GRDB also delivers `databaseDidCommit` for an empty deferred transaction (a `write {}`
    /// that early-returned wrote nothing to disk), so a commit only counts as evidence when the
    /// writer connection's total change count moved.
    private static let lastTotalChanges = Mutex(0)

    private final class CommitObserver: TransactionObserver, Sendable {
        func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
        func databaseDidChange(with event: DatabaseEvent) {}
        func databaseDidRollback(_ db: GRDB.Database) {}
        func databaseDidCommit(_ db: GRDB.Database) {
            let now = Date()
            let total = db.totalChangesCount
            let wroteRows = lastTotalChanges.withLock { last in
                defer { last = total }
                return total != last
            }
            guard wroteRows, bannerUp.withLock({ $0 }) else { return }
            Task { @MainActor in
                StorageHealth.highlander.commitSucceeded(at: now)
            }
        }
    }

}
