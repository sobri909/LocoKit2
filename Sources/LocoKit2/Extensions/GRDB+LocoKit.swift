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
    public func explain() throws {
        try Database.pool.read { db in
            let preparedRequest = try self.makePreparedRequest(db)
            print("SQL: \(preparedRequest.statement.sql)")
            for explain in try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + preparedRequest.statement.sql, arguments: preparedRequest.statement.arguments) {
                print("EXPLAIN: \(explain)")
            }
        }
    }
}
