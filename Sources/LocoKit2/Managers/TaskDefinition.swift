//
//  TaskDefinition.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 25/02/2025.
//

import Foundation
import BackgroundTasks

public struct TaskDefinition: Sendable {
    public typealias WorkHandler = @Sendable () async throws -> Void
    
    public init(
        identifier: String,
        minimumDelay: TimeInterval,
        requiresNetwork: Bool,
        requiresPower: Bool,
        workHandler: @escaping WorkHandler
    ) {
        self.identifier = identifier
        self.minimumDelay = minimumDelay
        self.requiresNetwork = requiresNetwork
        self.requiresPower = requiresPower
        self.workHandler = workHandler
    }

    let identifier: String
    let minimumDelay: TimeInterval
    let requiresNetwork: Bool
    let requiresPower: Bool
    let workHandler: WorkHandler
}
