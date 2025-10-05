//
//  GRDB+LocoKit.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 15/3/25.
//

import Foundation
import GRDB

extension DatabasePool {
    // perform a database read in a new top-level Task context to avoid cancellation
    public func uncancellableRead<T: Sendable>(_ operation: @escaping @Sendable (GRDB.Database) throws -> T) async throws -> T {
        try await Task {
            try await self.read(operation)
        }.value
    }
    
    // perform a database write in a new top-level Task context to avoid cancellation
    public func uncancellableWrite<T: Sendable>(_ operation: @escaping @Sendable (GRDB.Database) throws -> T) async throws -> T {
        try await Task {
            try await self.write(operation)
        }.value
    }
}

extension GRDB.Database {
    public func explain(query: String, arguments: StatementArguments = StatementArguments()) throws {
        for explain in try Row.fetchAll(self, sql: "EXPLAIN QUERY PLAN " + query, arguments: arguments) {
            print("EXPLAIN: \(explain)")
        }
    }
}

extension QueryInterfaceRequest {
    /// Explains only the main query (fast, but doesn't show prefetch queries from including(all:))
    ///
    /// NOTE: This only shows the main SQL query. Associations loaded with including(all:)
    /// are fetched via separate "prefetch" queries that use `WHERE foreignKey IN (...)`.
    /// These prefetch queries are efficient (2 queries total instead of N+1) but are not
    /// shown by this method.
    ///
    /// What GRDB does internally for including(all:):
    /// 1. Runs the main query you see here
    /// 2. Extracts foreign key values from results (e.g., all itemIds)
    /// 3. Runs: SELECT * FROM AssociatedTable WHERE foreignKey IN (id1, id2, ...)
    /// 4. Groups results and attaches to parent rows
    ///
    /// For 600 items with samples, this means 2 total queries, not 600!
    public func explain() throws {
        try Database.pool.read { db in
            let preparedRequest = try self.makePreparedRequest(db)
            print("SQL: \(preparedRequest.statement.sql)")
            for explain in try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + preparedRequest.statement.sql, arguments: preparedRequest.statement.arguments) {
                print("EXPLAIN: \(explain)")
            }
            print("\nNOTE: including(all:) associations are fetched via separate WHERE ... IN (...) queries")
            print("      (efficient batch loading, but not shown in this EXPLAIN)")
        }
    }
}
