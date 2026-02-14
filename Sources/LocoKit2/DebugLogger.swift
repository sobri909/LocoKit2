//
//  DebugLogger.swift
//
//  Created by Matt Greenfield on 2020-04-08
//

import Foundation
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

        Task { @MainActor in
            State.shared.osLogger(for: subsystem).info("\(message, privacy: .public)")

            if isMarker {
                State.shared.incrementFib()
            } else {
                State.shared.resetFib()
            }

            State.shared.writeToFile(line)

            State.shared.resetFibTimer()
        }
    }

    public static func error(_ message: String, subsystem: Subsystem) {
        let line = format(message, subsystem: subsystem, level: "ERROR")

        Task { @MainActor in
            State.shared.osLogger(for: subsystem).error("\(message, privacy: .public)")
            State.shared.resetFib()
            State.shared.writeToFile(line)
            State.shared.resetFibTimer()
        }
    }

    public static func error(_ error: Error, subsystem: Subsystem) {
        self.error("\(error)", subsystem: subsystem)
    }

    /// console only - no file write, for high-volume debug output
    public static func debug(_ message: String, subsystem: Subsystem) {
        Task { @MainActor in
            State.shared.osLogger(for: subsystem).debug("\(message, privacy: .public)")
        }
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

    // MARK: - MainActor-isolated state

    @MainActor
    private final class State {
        static let shared = State()

        var fibMarkerTimer: Timer?
        var fibn = 1
        var osLoggers: [Subsystem: os.Logger] = [:]

        func osLogger(for subsystem: Subsystem) -> os.Logger {
            if let cached = osLoggers[subsystem] { return cached }
            let newLogger = os.Logger(subsystem: "com.bigpaua.LocoKit", category: subsystem.rawValue)
            osLoggers[subsystem] = newLogger
            return newLogger
        }

        func writeToFile(_ line: String) {
            do {
                try line.appendLineTo(Log.sessionLogFileURL)
            } catch {
                os_log("Couldn't write to log file", type: .error)
            }
        }

        func resetFibTimer() {
            fibMarkerTimer?.invalidate()
            let currentFibn = fibn
            fibMarkerTimer = Timer.scheduledTimer(withTimeInterval: .minutes(fib(currentFibn)), repeats: false) { _ in
                Log.info("--\(currentFibn)--", subsystem: .misc)
            }
        }

        func incrementFib() {
            fibn += 1
        }

        func resetFib() {
            fibn = 1
        }

        func fib(_ n: Int) -> Int {
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
