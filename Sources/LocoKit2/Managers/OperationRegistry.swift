//
//  OperationRegistry.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-06-06
//

import Foundation
import Synchronization

public final class OperationRegistry: Sendable {

    public static let highlander = OperationRegistry()

    private let state = Mutex<[OperationCategory: Set<OperationHandle>]>([:])

    // MARK: - Public API

    public static func startOperation(
        _ category: OperationCategory,
        operation: String? = nil,
        objectKey: String? = nil,
        rejectDuplicates: Bool = false,
        maxConcurrent: Int? = nil
    ) -> OperationHandle? {
        highlander.state.withLock { operations in
            if rejectDuplicates, let handles = operations[category] {
                if handles.contains(where: { $0.operation == operation && $0.objectKey == objectKey }) {
                    return nil
                }
            }
            if let maxConcurrent, let operation {
                let count = (operations[category] ?? []).filter { $0.operation == operation }.count
                if count >= maxConcurrent { return nil }
            }
            let handle = OperationHandle(category: category, operation: operation, objectKey: objectKey)
            operations[category, default: []].insert(handle)
            return handle
        }
    }

    public static func endOperation(_ handle: OperationHandle) {
        highlander.state.withLock { operations in
            operations[handle.category]?.remove(handle)
            if operations[handle.category]?.isEmpty == true {
                operations.removeValue(forKey: handle.category)
            }
        }
    }

    // MARK: - Accessors

    public var activeOperations: [OperationCategory: Set<OperationHandle>] {
        state.withLock { $0 }
    }

    public var totalOperationCount: Int {
        state.withLock { $0.values.reduce(0) { $0 + $1.count } }
    }

    public func operationCount(for category: OperationCategory) -> Int {
        state.withLock { $0[category]?.count ?? 0 }
    }
}

// MARK: - Supporting types

public struct OperationHandle: Hashable, Sendable {
    public let id = UUID()
    public let category: OperationCategory
    public let operation: String?
    public let objectKey: String?
    public let startTime = Date()
}

public enum OperationCategory: String, CaseIterable, Codable, Sendable {
    case timeline
    case places
    case activityTypes
    case calendar
    case importExport
    case health
}
