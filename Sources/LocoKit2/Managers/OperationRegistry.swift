//
//  OperationRegistry.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 6/06/2025.
//

import Foundation

@MainActor
@Observable
public class OperationRegistry {
    
    public static let highlander = OperationRegistry()
    
    // track active operations by category
    public private(set) var activeOperations: [OperationCategory: Set<OperationHandle>] = [:]
    
    // MARK: - Public API
    
    public static func startOperation(
        _ category: OperationCategory, 
        operation: String? = nil, 
        objectKey: String? = nil,
        rejectDuplicates: Bool = false
    ) async -> OperationHandle? {
        if rejectDuplicates && highlander.hasMatchingOperation(category, operation: operation, objectKey: objectKey) {
            return nil
        }
        return highlander.startOperation(category, operation: operation, objectKey: objectKey)
    }
    
    public static func endOperation(_ handle: OperationHandle) async {
        highlander.endOperation(handle)
    }
    
    // MARK: - Instance methods
    
    private func hasMatchingOperation(_ category: OperationCategory, operation: String?, objectKey: String?) -> Bool {
        guard let handles = activeOperations[category] else { return false }
        return handles.contains { handle in
            handle.operation == operation && handle.objectKey == objectKey
        }
    }
    
    public func startOperation(_ category: OperationCategory, operation: String? = nil, objectKey: String? = nil) -> OperationHandle {
        let handle = OperationHandle(category: category, operation: operation, objectKey: objectKey)
        
        if activeOperations[category] == nil {
            activeOperations[category] = []
        }
        activeOperations[category]?.insert(handle)
        
        return handle
    }
    
    public func endOperation(_ handle: OperationHandle) {
        activeOperations[handle.category]?.remove(handle)
        if activeOperations[handle.category]?.isEmpty == true {
            activeOperations.removeValue(forKey: handle.category)
        }
    }
    
    // MARK: - Convenience accessors
    
    public var totalOperationCount: Int {
        activeOperations.values.reduce(0) { $0 + $1.count }
    }
    
    public func operationCount(for category: OperationCategory) -> Int {
        activeOperations[category]?.count ?? 0
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