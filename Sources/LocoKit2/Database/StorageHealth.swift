//
//  StorageHealth.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-21
//

import Foundation
import Observation

/// BIG-745: the user-visible state of "SQLite is refusing writes because the volume is full".
///
/// Fed by `StorageHealthMonitor` (the process-wide SQLite error hook) and cleared by the next
/// successful commit on the main pool once the episode has been quiet for `clearFloor`. The
/// flag exists so the app can say "your edits and recording aren't landing" while it is true
/// and say nothing once writes work again — no dismiss, no user action, self-clearing.
@MainActor
@Observable
public final class StorageHealth {

    public static let highlander = StorageHealth()

    /// A successful commit clears the flag only once this long has passed since the last
    /// failure: SQLITE_FULL is allocation-dependent, so a small write can commit mid-episode
    /// while larger ones still fail, and a banner that flickers off on one lucky commit
    /// would tell the user the phone is fine when it isn't.
    public static let clearFloor: TimeInterval = 60

    public private(set) var storageFull = false
    public private(set) var lastFailure: Date?

    private var episodeStart: Date?

    private init() {}

    func recordFailure(_ description: String, at date: Date = Date()) {
        lastFailure = date
        if !storageFull {
            storageFull = true
            episodeStart = date
            StorageHealthMonitor.setBannerUp(true)
            Log.error("Storage full: SQLite refused a write (\(description)) — showing the storage-full banner", subsystem: .database)
        }
    }

    func commitSucceeded(at date: Date = Date()) {
        guard storageFull, let lastFailure else { return }
        guard date.timeIntervalSince(lastFailure) >= Self.clearFloor else { return }
        storageFull = false
        StorageHealthMonitor.setBannerUp(false)
        let duration = episodeStart.map { Int(date.timeIntervalSince($0)) } ?? 0
        episodeStart = nil
        Log.info("Storage full cleared: a commit succeeded \(Int(date.timeIntervalSince(lastFailure)))s after the last failure (episode \(duration)s)", subsystem: .database)
    }

}
