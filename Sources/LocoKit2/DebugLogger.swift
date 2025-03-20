//
//  DebugLogger.swift
//
//  Created by Matt Greenfield on 8/4/20.
//

import Foundation
import os.log
import Logging
import LoggingFormatAndPipe

internal let logger = DebugLogger.logger

@Observable
public final class DebugLogger: LoggingFormatAndPipe.Pipe, @unchecked Sendable {

    public static let highlander = DebugLogger()

    public enum Subsystem: String, CaseIterable {
        case misc, lifecycle, locomotion, database, appgroup, tasks, timeline, activitytypes, places, healthkit, ui
    }

    public static let logger = Logger(label: "com.bigpaua.LocoKit.main") { _ in
        return LoggingFormatAndPipe.Handler(
            formatter: DebugLogger.LogDateFormatter(),
            pipe: DebugLogger.highlander
        )
    }

    private var fibMarkerTimer: Timer?
    private var fibn = 1

    private init() {
        do {
            try FileManager.default.createDirectory(at: Self.logsDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            os_log("Couldn't create logs dir", type: .error)
        }

        let filename = ISO8601DateFormatter.string(
            from: .now, timeZone: TimeZone.current,
            formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        )
        self.sessionLogFileURL = Self.logsDir.appendingPathComponent("\(filename).log")
        
        updateLogFileURLs()
    }

    public func handle(_ formattedLogLine: String) {
        Task { @MainActor in
            do {
                try formattedLogLine.appendLineTo(self.sessionLogFileURL)
            } catch {
                os_log("Couldn't write to log file", type: .error)
            }

            print(formattedLogLine)

            self.fibMarkerTimer?.invalidate()
            self.fibMarkerTimer = Timer.scheduledTimer(withTimeInterval: .minutes(fib(self.fibn)), repeats: false) { _ in
                Self.logger.info("--\(self.fibn)--")
            }
        }
    }

    public func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        updateLogFileURLs()
    }

    // MARK: -

    static var logsDir: URL {
        try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    public let sessionLogFileURL: URL

    private func createSessionLogURL(inDir: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let filename = formatter.string(from: Date())
        return inDir.appendingPathComponent(filename + ".log")
    }

    public var logFileURLs: [URL]?

    public func updateLogFileURLs() {
        do {
            let files = try FileManager.default
                .contentsOfDirectory(at: Self.logsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])
            logFileURLs = files
                .filter { !$0.hasDirectoryPath && $0.pathExtension.lowercased() == "log" }
                .sorted { $0.path > $1.path }

        } catch {
            print(error)
        }
    }

    class LogDateFormatter: LoggingFormatAndPipe.Formatter {
        var timestampFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter
        }()

        func processLog(level: Logging.Logger.Level, message: Logging.Logger.Message, prettyMetadata: String?, file: String, function: String, line: UInt) -> String {
            if message.description.hasPrefix("--") {
                DebugLogger.highlander.fibn += 1
            } else {
                DebugLogger.highlander.fibn = 1
            }
            let timestamp = self.timestampFormatter.string(from: .now)
            if level == .error {
                return "[\(timestamp)] [ERROR] \(message)"
            }
            return "[\(timestamp)] \(message)"
        }
    }

}

func fib (_ n: Int) -> Int {
    guard n > 1 else {return n}
    return fib(n - 1) + fib(n - 2)
}

extension Logging.Logger {
    @inlinable
    public func info(_ message: String, subsystem: DebugLogger.Subsystem, source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.info("[\(subsystem.rawValue.uppercased())] \(message)", source: source(), file: file, function: function, line: line)
    }
    
    @inlinable
    public func error(_ message: String, subsystem: DebugLogger.Subsystem, source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error("[\(subsystem.rawValue.uppercased())] \(message)", source: source(), file: file, function: function, line: line)
    }
    
    @inlinable
    public func error(_ error: Error, subsystem: DebugLogger.Subsystem, source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error("[\(subsystem.rawValue.uppercased())] \(error)", source: source(), file: file, function: function, line: line)
    }
}
