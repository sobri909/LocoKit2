//
//  TimelineObserver.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-08-12.
//

import Foundation
import GRDB
import os

/// Provides real-time timeline change notifications intended for UI updates and foreground processing.
///
/// For optimal resource usage, applications should disable the observer during background operation by setting
/// `enabled = false`. Observer streams will pause while disabled and automatically resume when re-enabled.
///
/// Example usage in an app's lifecycle:
/// ```
/// func enteredBackground() {
///     TimelineObserver.highlander.enabled = false
/// }
///
/// func becameActive() {
///     TimelineObserver.highlander.enabled = true
/// }
/// ```
public final class TimelineObserver: TransactionObserver, Sendable {

    public static let highlander = TimelineObserver()

    private let observedTables = ["TimelineItemBase", "TimelineItemVisit", "TimelineItemTrip"]

    nonisolated(unsafe)
    private var changedRowIds: [String: Set<Int64>] = [:]

    nonisolated(unsafe)
    private var continuations: [UUID: AsyncStream<DateInterval>.Continuation] = [:]

    private let lock = OSAllocatedUnfairLock()

    nonisolated(unsafe)
    public var enabled = true {
        didSet {
            if enabled && !oldValue {
                processPendingChanges()
            }
        }
    }

    // MARK: - Observable Sream

    public func changesStream() -> AsyncStream<DateInterval> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    self.continuations[id] = nil
                }
            }
        }
    }

    // MARK: - Change Processing

    private func processPendingChanges() {
        let rowIds = lock.withLock { changedRowIds }
        guard !rowIds.isEmpty else { return }

        lock.withLock { changedRowIds.removeAll() }
        Task { await process(rowIds: rowIds) }
    }

    private func process(rowIds: [String: Set<Int64>]) async {
        guard let handle = await OperationRegistry.startOperation(.timeline, operation: "TimelineObserver.process(rowIds:)", objectKey: "\(rowIds.values.reduce(0) { $0 + $1.count }) changes") else { return }
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        let baseRowIds = rowIds["TimelineItemBase", default: []].map(String.init).joined(separator: ",")
        let visitRowIds = rowIds["TimelineItemVisit", default: []].map(String.init).joined(separator: ",")
        let tripRowIds = rowIds["TimelineItemTrip", default: []].map(String.init).joined(separator: ",")

        // use UNION to force efficient ROWID lookups instead of full table scans
        let query = """
                SELECT DISTINCT startDate, endDate FROM (
                    SELECT startDate, endDate 
                    FROM TimelineItemBase 
                    WHERE ROWID IN (\(baseRowIds.isEmpty ? "NULL" : baseRowIds))
                    
                    UNION ALL
                    
                    SELECT base.startDate, base.endDate 
                    FROM TimelineItemBase base
                    INNER JOIN TimelineItemVisit visit ON base.id = visit.itemId
                    WHERE visit.ROWID IN (\(visitRowIds.isEmpty ? "NULL" : visitRowIds))
                    
                    UNION ALL
                    
                    SELECT base.startDate, base.endDate 
                    FROM TimelineItemBase base
                    INNER JOIN TimelineItemTrip trip ON base.id = trip.itemId
                    WHERE trip.ROWID IN (\(tripRowIds.isEmpty ? "NULL" : tripRowIds))
                )
            """
        do {
            let dateRanges = try Database.pool
                .read { try Row.fetchAll($0, sql: query) }
                .compactMap { row -> DateInterval? in
                    guard let startDate = row["startDate"] as Date? else { return nil }
                    guard let endDate = row["endDate"] as Date? else { return nil }
                    return DateInterval(start: startDate, end: endDate)
                }

            for dateRange in dateRanges {
                notifyChange(dateRange)
            }

        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    private func notifyChange(_ dateRange: DateInterval) {
        let continuations = lock.withLock { self.continuations }
        for continuation in continuations.values {
            continuation.yield(dateRange)
        }
    }

    // MARK: - TransactionObserver

    public func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observedTables.contains(eventKind.tableName)
    }

    public func databaseDidChange(with event: DatabaseEvent) {
        let tableName = event.tableName

        // filter out tables we don't observe (GRDB sends RTree events despite observes() returning false)
        guard observedTables.contains(tableName) else { return }

        let rowID = event.rowID
        lock.withLock { _ = changedRowIds[tableName, default: []].insert(rowID) }
    }

    public func databaseDidCommit(_ db: GRDB.Database) {
        guard enabled else { return }
        processPendingChanges()
    }

    public func databaseDidRollback(_ db: GRDB.Database) {
        lock.withLock { changedRowIds.removeAll() }
    }

}
