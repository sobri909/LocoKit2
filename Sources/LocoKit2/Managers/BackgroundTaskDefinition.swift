//
//  BackgroundTaskDefinition.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 25/02/2025.
//

import Foundation
import BackgroundTasks

public struct BackgroundTaskDefinition: Sendable {
    public typealias WorkHandler = @Sendable () async throws -> Void
    
    public init(
        identifier: String,
        displayName: String,
        minimumDelay: TimeInterval,
        requiresNetwork: Bool,
        requiresPower: Bool,
        foregroundThreshold: TimeInterval? = nil,
        workHandler: @escaping WorkHandler
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.minimumDelay = minimumDelay
        self.requiresNetwork = requiresNetwork
        self.requiresPower = requiresPower
        self.foregroundThreshold = foregroundThreshold
        self.workHandler = workHandler
    }

    let identifier: String
    let displayName: String
    let minimumDelay: TimeInterval
    let requiresNetwork: Bool
    let requiresPower: Bool
    let foregroundThreshold: TimeInterval?
    let workHandler: WorkHandler
}
