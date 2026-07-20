//
//  RecordingStats.swift
//  Arc Timeline
//
//  Created by Claude on 2026-07-19
//

import Foundation
import GRDB
import Synchronization

/// In-memory accumulator feeding DailyRecordingStats rows (BIG-427).
///
/// Mutex-protected (not actor-based) deliberately: increments happen in
/// recording-critical, all-day-every-day pathways where actor hops would add
/// cost and could subtly reorder outcomes — we're here to observe, not affect.
/// Nothing writes to the database per event; deltas accumulate in memory and
/// flush on state transitions / hourly / on demand (app lifecycle). Process
/// death loses at most the unflushed window — acceptable for stats.
public enum RecordingStats {

    public enum Counter: CaseIterable, Sendable {
        case restart, wakeup, wakeupTimeout, chainStall, appLaunch
    }

    // MARK: - Internal state

    private struct DayDelta {
        var secondsByState: [RecordingState: Double] = [:]
        var counts: [Counter: Int] = [:]
        var samples: Int = 0
    }

    private struct State {
        var pending: [String: DayDelta] = [:]  // dayKey -> unflushed deltas
        var currentState: RecordingState?
        var currentStateSince: Date = .now
        var lastFlush: Date = .now
    }

    private static let state = Mutex(State())

    private static let flushInterval: TimeInterval = 60 * 60

    // MARK: - Recording API

    /// Call on every recording state transition. Credits elapsed time to the
    /// OUTGOING state (split across midnight boundaries), then starts timing
    /// the new state.
    public static func recordStateChange(to newState: RecordingState) {
        let wantsFlush = state.withLock { s in
            accrueCurrentState(&s, upTo: .now)
            s.currentState = newState
            return s.lastFlush.age > flushInterval
        }
        if wantsFlush { scheduleFlush() }
    }

    public static func increment(_ counter: Counter) {
        let wantsFlush = state.withLock { s in
            s.pending[DailyRecordingStats.dayKey(), default: DayDelta()].counts[counter, default: 0] += 1
            return s.lastFlush.age > flushInterval
        }
        if wantsFlush { scheduleFlush() }
    }

    public static func incrementSamples(by count: Int = 1) {
        state.withLock { s in
            s.pending[DailyRecordingStats.dayKey(), default: DayDelta()].samples += count
        }
    }

    // MARK: - Flushing

    /// Accrue in-flight state time, snapshot pending deltas, and persist.
    /// Safe to call from anywhere; the db write happens outside the lock.
    public static func flush() async {
        let snapshot: [String: DayDelta] = state.withLock { s in
            accrueCurrentState(&s, upTo: .now)
            let pending = s.pending
            s.pending = [:]
            s.lastFlush = .now
            return pending
        }

        guard !snapshot.isEmpty else { return }

        do {
            try await Database.pool.write { db in
                for (dayKey, delta) in snapshot {
                    var row = try DailyRecordingStats
                        .filter(Column("dayKey") == dayKey)
                        .fetchOne(db) ?? DailyRecordingStats(dayKey: dayKey)
                    row.secondsRecording += delta.secondsByState[.recording] ?? 0
                    row.secondsSleeping += (delta.secondsByState[.sleeping] ?? 0)
                        + (delta.secondsByState[.deepSleeping] ?? 0)
                    row.secondsWakeup += delta.secondsByState[.wakeup] ?? 0
                    row.secondsStandby += delta.secondsByState[.standby] ?? 0
                    row.restartCount += delta.counts[.restart] ?? 0
                    row.wakeupCount += delta.counts[.wakeup] ?? 0
                    row.wakeupTimeoutCount += delta.counts[.wakeupTimeout] ?? 0
                    row.chainStallCount += delta.counts[.chainStall] ?? 0
                    row.appLaunchCount += delta.counts[.appLaunch] ?? 0
                    row.samplesRecorded += delta.samples
                    row.lastSaved = .now
                    row.utcOffset = TimeZone.current.secondsFromGMT()
                    try row.save(db)
                }
            }
        } catch {
            // stats are best-effort; deltas for this flush are lost, not retried
            Log.error(error, subsystem: .database)
        }
    }

    private static func scheduleFlush() {
        Task { await flush() }
    }

    // MARK: - Accrual

    /// Credit elapsed time since `currentStateSince` to the current state,
    /// splitting across local-midnight boundaries so multi-day stretches
    /// (overnight sleeps) attribute to the correct day rows.
    private static func accrueCurrentState(_ s: inout State, upTo end: Date) {
        defer { s.currentStateSince = end }
        guard let current = s.currentState else { return }
        guard end > s.currentStateSince else { return }

        var cursor = s.currentStateSince
        let calendar = Calendar.current
        while cursor < end {
            // date(byAdding:) not +24h: DST-change days aren't 24 hours long
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor))
                ?? cursor.addingTimeInterval(24 * 60 * 60)
            let segmentEnd = min(end, nextMidnight)
            let seconds = segmentEnd.timeIntervalSince(cursor)
            s.pending[DailyRecordingStats.dayKey(for: cursor), default: DayDelta()]
                .secondsByState[current, default: 0] += seconds
            cursor = segmentEnd
        }
    }
}
