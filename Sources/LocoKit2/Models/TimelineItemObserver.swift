//
//  TimelineItemObserver.swift
//  LocoKit2
//
//  Created by Claude on 2026-03-11
//

import Foundation
import GRDB
import Synchronization

/// Provides real-time item-level change notifications for TimelineLinkedList cache updates.
///
/// Replaces per-item ValueObservation (which saturated the GRDB reader pool) with a single
/// TransactionObserver that captures rowIDs during writes and batch-resolves them to item IDs.
///
/// Consumers receive `Set<String>` (changed item IDs) and filter locally against their own tracked items.
public final class TimelineItemObserver: TransactionObserver, Sendable {

    public static let highlander = TimelineItemObserver()

    private let observedTables = ["TimelineItemBase", "TimelineItemVisit", "TimelineItemTrip"]

    private struct State {
        var changedRowIds: [String: Set<Int64>] = [:]
        var continuations: [UUID: AsyncStream<Set<String>>.Continuation] = [:]
    }

    private let state = Mutex(State())

    // MARK: - Observable Stream

    public func changesStream() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let id = UUID()
            state.withLock { $0.continuations[id] = continuation }
            continuation.onTermination = { @Sendable _ in
                self.state.withLock { $0.continuations[id] = nil }
            }
        }
    }

    // MARK: - Change Processing

    private func processPendingChanges() {
        let rowIds = state.withLock {
            let ids = $0.changedRowIds
            $0.changedRowIds.removeAll()
            return ids
        }
        guard !rowIds.isEmpty else { return }
        Task { await process(rowIds: rowIds) }
    }

    private func process(rowIds: [String: Set<Int64>]) async {
        let baseRowIds = rowIds["TimelineItemBase", default: []].map(String.init).joined(separator: ",")
        let visitRowIds = rowIds["TimelineItemVisit", default: []].map(String.init).joined(separator: ",")
        let tripRowIds = rowIds["TimelineItemTrip", default: []].map(String.init).joined(separator: ",")

        // Visit and Trip PKs (itemId) are the same UUID as Base's id,
        // so no joins needed — read the ID directly from each table's row
        let query = """
                SELECT DISTINCT id FROM (
                    SELECT id
                    FROM TimelineItemBase
                    WHERE ROWID IN (\(baseRowIds.isEmpty ? "NULL" : baseRowIds))

                    UNION ALL

                    SELECT itemId AS id
                    FROM TimelineItemVisit
                    WHERE ROWID IN (\(visitRowIds.isEmpty ? "NULL" : visitRowIds))

                    UNION ALL

                    SELECT itemId AS id
                    FROM TimelineItemTrip
                    WHERE ROWID IN (\(tripRowIds.isEmpty ? "NULL" : tripRowIds))
                )
            """
        do {
            let changedItemIds = try await Database.pool
                .read { try String.fetchSet($0, sql: query) }

            guard !changedItemIds.isEmpty else { return }
            notifyChanges(changedItemIds)

        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    private func notifyChanges(_ changedItemIds: Set<String>) {
        let continuations = state.withLock { $0.continuations }
        for continuation in continuations.values {
            continuation.yield(changedItemIds)
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
        state.withLock { _ = $0.changedRowIds[tableName, default: []].insert(rowID) }
    }

    public func databaseDidCommit(_ db: GRDB.Database) {
        processPendingChanges()
    }

    public func databaseDidRollback(_ db: GRDB.Database) {
        state.withLock { $0.changedRowIds.removeAll() }
    }

}
