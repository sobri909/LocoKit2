//
//  ActivityTypesActor.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-09-03.
//

import Foundation

@globalActor
public actor ActivityTypesActor: GlobalActor {
    public static let shared = ActivityTypesActor()

    public static var queue: DispatchQueue { executor.queue }

    private static let executor = CustomSerialExecutor(label: "ActivityTypeQueue")

    public static let sharedUnownedExecutor: UnownedSerialExecutor = ActivityTypesActor.executor.asUnownedSerialExecutor()

    nonisolated
    public var unownedExecutor: UnownedSerialExecutor { Self.sharedUnownedExecutor }
}

