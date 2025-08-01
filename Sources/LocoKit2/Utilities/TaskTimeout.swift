//
//  TaskTimeout.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-08-01.
//

import Foundation

/// Utilities for running async tasks with timeouts
public enum TaskTimeout {
    
    /// Executes an async operation with a timeout. Returns nil if the operation times out.
    /// - Parameters:
    ///   - seconds: The timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation, or nil if it timed out
    public static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T? {
        return try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                return try await operation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            
            let result = try await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }
}