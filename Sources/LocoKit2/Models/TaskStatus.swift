//
//  TaskStatus.swift
//  LocoKit2
//
//  Created on 2025-02-26.
//

import Foundation
import GRDB

public struct TaskStatus: FetchableRecord, PersistableRecord, Identifiable, Codable, Sendable {
    public init(identifier: String, state: TaskState, minimumDelay: TimeInterval, lastUpdated: Date) {
        self.identifier = identifier
        self.state = state
        self.minimumDelay = minimumDelay
        self.lastUpdated = lastUpdated
    }

    public let identifier: String
    public var state: TaskState
    public var minimumDelay: TimeInterval
    public var lastUpdated: Date
    public var lastStarted: Date?
    public var lastExpired: Date?
    public var lastCompleted: Date?

    public var id: String { identifier }

    var overdueBy: TimeInterval {
        guard let lastCompleted else { return 0 }
        return lastCompleted.age - minimumDelay
    }

    public enum TaskState: String, Codable, CaseIterable, Sendable {
        case running, expired, unfinished, completed, scheduled, registered
    }
}
