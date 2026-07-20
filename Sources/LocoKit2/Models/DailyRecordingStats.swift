//
//  DailyRecordingStats.swift
//  Arc Timeline
//
//  Created by Claude on 2026-07-19
//

import Foundation
import GRDB

/// One row per local calendar day of recording-system health stats (BIG-427).
///
/// Fed by in-memory accumulation in LocomotionManager (state-time accrual on
/// transitions, counter increments for high-frequency events), flushed on
/// transitions / hourly / app backgrounding — never a write per event.
/// Day key is the LOCAL calendar day (matches how iOS presents battery days
/// to users); `utcOffset` records the timezone in effect at last save so
/// travel-day rows remain interpretable.
public struct DailyRecordingStats: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    /// "yyyy-MM-dd" in the local calendar day the stats accrued to
    public var dayKey: String
    public var lastSaved: Date = .now
    public var utcOffset: Int = TimeZone.current.secondsFromGMT()

    // Time in each recording state (seconds, accrued across the day)
    public var secondsRecording: Double = 0
    public var secondsSleeping: Double = 0
    public var secondsWakeup: Double = 0
    public var secondsStandby: Double = 0

    // Event counters
    public var restartCount: Int = 0        // requestLocationIfStale() restarts
    public var wakeupCount: Int = 0         // sleep-cycle wakeups begun
    public var wakeupTimeoutCount: Int = 0  // wakeups ended by timeout
    public var chainStallCount: Int = 0     // BIG-596 watchdog re-arms
    public var appLaunchCount: Int = 0      // process launches during the day
    public var samplesRecorded: Int = 0     // samples persisted to db

    public var id: String { dayKey }

    // MARK: -

    public static func dayKey(for date: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    // MARK: - PersistableRecord

    public static let databaseTableName = "DailyRecordingStats"

    // MARK: - Columns

    public enum Columns {
        public static let dayKey = Column(CodingKeys.dayKey)
        public static let lastSaved = Column(CodingKeys.lastSaved)
        public static let utcOffset = Column(CodingKeys.utcOffset)
        public static let secondsRecording = Column(CodingKeys.secondsRecording)
        public static let secondsSleeping = Column(CodingKeys.secondsSleeping)
        public static let secondsWakeup = Column(CodingKeys.secondsWakeup)
        public static let secondsStandby = Column(CodingKeys.secondsStandby)
        public static let restartCount = Column(CodingKeys.restartCount)
        public static let wakeupCount = Column(CodingKeys.wakeupCount)
        public static let wakeupTimeoutCount = Column(CodingKeys.wakeupTimeoutCount)
        public static let chainStallCount = Column(CodingKeys.chainStallCount)
        public static let appLaunchCount = Column(CodingKeys.appLaunchCount)
        public static let samplesRecorded = Column(CodingKeys.samplesRecorded)
    }
}
