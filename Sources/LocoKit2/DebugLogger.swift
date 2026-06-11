//
//  DebugLogger.swift
//
//  Created by Matt Greenfield on 2020-04-08
//

import Foundation
import Synchronization
import os

public enum Log {

    public enum Subsystem: String, CaseIterable, Sendable {
        case misc, lifecycle, locomotion, database, appgroup, tasks, timeline, activitytypes, places, healthkit, ui,
             importing, exporting
    }

    // MARK: - Public API

    public static func info(_ message: String, subsystem: Subsystem) {
        let isMarker = message.hasPrefix("--")
        let line = isMarker ? format(message) : format(message, subsystem: subsystem)

        // os_log and file write: immediate, on caller's thread
        State.shared.osLogger(for: subsystem).info("\(message, privacy: .public)")
        State.shared.writeToFile(line)

        // fib state + timer: on MainActor (timer needs run loop)
        // Task.detached to avoid inheriting cancellation from caller
        Task.detached { @MainActor in
            if isMarker {
                MarkerTimer.shared.incrementFib()
            } else {
                MarkerTimer.shared.resetFib()
            }
            MarkerTimer.shared.schedule()
        }
    }

    public static func error(_ message: String, subsystem: Subsystem) {
        let line = format(message, subsystem: subsystem, level: "ERROR")

        State.shared.osLogger(for: subsystem).error("\(message, privacy: .public)")
        State.shared.writeToFile(line)

        Task.detached { @MainActor in
            MarkerTimer.shared.resetFib()
            MarkerTimer.shared.schedule()
        }
    }

    public static func error(_ error: Error, subsystem: Subsystem) {
        self.error("\(error)", subsystem: subsystem)
    }

    /// console only - no file write, for high-volume debug output
    public static func debug(_ message: String, subsystem: Subsystem) {
        State.shared.osLogger(for: subsystem).debug("\(message, privacy: .public)")
    }

    // MARK: - Wedge detector context hook (BIG-595)

    /// Optional app-supplied context appended to task-pool wedge log lines (e.g. counts
    /// of known cooperative-pool-blocking operations in flight). Must be cheap and
    /// non-blocking — it's called synchronously on the main thread from a Timer.
    public static func setWedgeContextProvider(_ provider: @escaping @Sendable () -> String) {
        wedgeContextProvider.withLock { $0 = provider }
    }

    private static let wedgeContextProvider = Mutex<(@Sendable () -> String)?>(nil)

    fileprivate static func wedgeContext() -> String? {
        wedgeContextProvider.withLock { $0 }?()
    }

    /// Raw write that bypasses the fib-marker machinery: wedge lines must not reset the
    /// fib cadence, so detector output stays naturally fib-throttled during a long wedge.
    fileprivate static func writeWedgeLine(_ message: String) {
        State.shared.osLogger(for: .misc).error("\(message, privacy: .public)")
        State.shared.writeToFile(format(message, subsystem: .misc, level: "ERROR"))
    }

    // MARK: - File management

    public static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public static func logFileURLs() -> [URL] {
        do {
            let files = try FileManager.default
                .contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])
            return files
                .filter { !$0.hasDirectoryPath && $0.pathExtension.lowercased() == "log" }
                .sorted { $0.path > $1.path }
        } catch {
            os_log("Couldn't read logs directory: %{public}@", type: .error, error.localizedDescription)
            return []
        }
    }

    /// BIG-431: delete log files older than the given age threshold. Skips
    /// the current session's log file as belt-and-braces (it'll be newer
    /// than any reasonable threshold anyway). Uses content modification
    /// date — last-written-to time — rather than creation date, since
    /// long-lived sessions can have creation dates well before their
    /// final modification.
    public static func cleanupOldLogs(olderThan maxAge: TimeInterval = .days(30)) {
        let now = Date()
        let currentSessionURL = sessionLogFileURL
        var deletedCount = 0

        for url in logFileURLs() {
            if url == currentSessionURL { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate else { continue }
            if now.timeIntervalSince(modDate) <= maxAge { continue }
            do {
                try delete(url)
                deletedCount += 1
            } catch {
                os_log("Couldn't delete old log %{public}@: %{public}@", type: .error, url.lastPathComponent, error.localizedDescription)
            }
        }

        if deletedCount > 0 {
            let plural = deletedCount == 1 ? "file" : "files"
            Log.info("cleanupOldLogs: removed \(deletedCount) log \(plural) older than \(Int(maxAge / .days(1))) days", subsystem: .lifecycle)
        }
    }

    // MARK: - Thread-safe state (os_log + file write)

    private final class State: Sendable {
        static let shared = State()

        private let osLoggers = Mutex<[Subsystem: os.Logger]>([:])
        private let fileLock = NSLock()

        func osLogger(for subsystem: Subsystem) -> os.Logger {
            osLoggers.withLock { loggers in
                if let cached = loggers[subsystem] { return cached }
                let newLogger = os.Logger(subsystem: "com.bigpaua.LocoKit", category: subsystem.rawValue)
                loggers[subsystem] = newLogger
                return newLogger
            }
        }

        func writeToFile(_ line: String) {
            fileLock.lock()
            defer { fileLock.unlock() }
            do {
                try line.appendLineTo(Log.sessionLogFileURL)
            } catch {
                os_log("Couldn't write to log file", type: .error)
            }
        }
    }

    // MARK: - Fib marker timer (MainActor — needs run loop for Timer)

    @MainActor
    private final class MarkerTimer {
        static let shared = MarkerTimer()

        private var timer: Timer?
        private var fibn = 1

        // task-pool wedge detector state (BIG-595). The probe is a plain detached Task,
        // so it can only land if the cooperative pool is scheduling jobs. The run-loop
        // Timer + MainActor-direct jobs survive a pool wedge (field-verified in the
        // BIG-595 logs), so this timer is the right place to stand watch from.
        private var lastProbeSent: Date?
        nonisolated private static let lastProbeLanded = Mutex<Date?>(nil)

        func schedule() {
            timer?.invalidate()
            let currentFibn = fibn
            timer = Timer.scheduledTimer(withTimeInterval: .minutes(fib(currentFibn)), repeats: false) { _ in
                MainActor.assumeIsolated {
                    MarkerTimer.shared.checkTaskPoolLiveness()
                }
                Log.info("--\(currentFibn)--", subsystem: .misc)
            }
        }

        func checkTaskPoolLiveness() {
            if let sent = lastProbeSent {
                let landed = Self.lastProbeLanded.withLock { $0 }
                if landed == nil || landed! < sent {
                    let staleness = Int(Date().timeIntervalSince(sent))
                    var message = "Task-pool probe unanswered (\(staleness)s) — cooperative pool suspected wedged"
                    if let context = Log.wedgeContext() { message += " — \(context)" }
                    Log.writeWedgeLine(message)
                    return // leave the unanswered probe standing; staleness keeps accumulating
                }
            }
            lastProbeSent = .now
            Task.detached {
                MarkerTimer.lastProbeLanded.withLock { $0 = .now }
            }
        }

        func incrementFib() { fibn += 1 }
        func resetFib() { fibn = 1 }

        private func fib(_ n: Int) -> Int {
            guard n > 1 else { return n }
            return fib(n - 1) + fib(n - 2)
        }
    }

    // MARK: - File logging

    public static let logsDir: URL = {
        let dir = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Logs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            os_log("Couldn't create logs dir", type: .error)
        }
        return dir
    }()

    public static let sessionLogFileURL: URL = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return logsDir.appendingPathComponent("\(timestamp).log")
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // MARK: - Private

    private static func format(_ message: String, subsystem: Subsystem? = nil, level: String? = nil) -> String {
        let timestamp = timestampFormatter.string(from: .now)
        var parts = ["[\(timestamp)]"]
        if let level { parts.append("[\(level)]") }
        if let subsystem { parts.append("[\(subsystem.rawValue.uppercased())]") }
        parts.append(message)
        return parts.joined(separator: " ")
    }
}
