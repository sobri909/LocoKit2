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
