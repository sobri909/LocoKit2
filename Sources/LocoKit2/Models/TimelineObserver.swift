//
//  TimelineObserver.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-08-12.
//

import Foundation
import GRDB
import os

public final class TimelineObserver: TransactionObserver, Sendable {

    public static let highlander = TimelineObserver()

    private let observedTables = ["TimelineItemBase", "TimelineItemVisit", "TimelineItemTrip"]

    nonisolated(unsafe)
    private var changedRowIds: [String: Set<Int64>] = [:]

    nonisolated(unsafe)
    private var continuations: [UUID: AsyncStream<DateInterval>.Continuation] = [:]

    private let lock = OSAllocatedUnfairLock()

    // MARK: -

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

    private func notifyChange(_ dateRange: DateInterval) {
        let continuations = lock.withLock { self.continuations }
        for continuation in continuations.values {
            continuation.yield(dateRange)
        }
    }

    private func processChangedRows(_ rowIds: [String: Set<Int64>]) async {
        let baseRowIds = rowIds["TimelineItemBase", default: []].map(String.init).joined(separator: ",")
        let visitRowIds = rowIds["TimelineItemVisit", default: []].map(String.init).joined(separator: ",")
        let tripRowIds = rowIds["TimelineItemTrip", default: []].map(String.init).joined(separator: ",")

        let query = """
                SELECT base.startDate, base.endDate
                FROM TimelineItemBase AS base
                LEFT JOIN TimelineItemVisit AS visit ON base.id = visit.itemId
                LEFT JOIN TimelineItemTrip AS trip ON base.id = trip.itemId
                WHERE
                    base.ROWID IN (\(baseRowIds))
                    OR visit.ROWID IN (\(visitRowIds))
                    OR trip.ROWID IN (\(tripRowIds))
            """
        do {
            let dateRanges = try await Database.pool
                .read { try Row.fetchAll($0, sql: query) }
                .map { DateInterval(start: $0["startDate"] as Date, end: $0["endDate"] as Date) }

            for dateRange in dateRanges {
                notifyChange(dateRange)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - TransactionObserver

    public func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observedTables.contains(eventKind.tableName)
    }

    public func databaseDidChange(with event: DatabaseEvent) {
        let rowID = event.rowID
        let tableName = event.tableName
        lock.withLock { _ = changedRowIds[tableName, default: []].insert(rowID) }
    }

    public func databaseDidCommit(_ db: GRDB.Database) {
        let rowIds = lock.withLock { changedRowIds }
        if !rowIds.isEmpty {
            lock.withLock { changedRowIds.removeAll() }
            Task { await processChangedRows(rowIds) }
        }
    }

    public func databaseDidRollback(_ db: GRDB.Database) {
        lock.withLock { changedRowIds.removeAll() }
    }

}
