//
//  TimelineActor.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-08-13.
//

import Foundation

@globalActor
public actor TimelineActor: GlobalActor {
    public static let shared = TimelineActor()

    public static var queue: DispatchQueue { executor.queue }

    private static let executor = TimelineActorSerialExecutor()

    public static let sharedUnownedExecutor: UnownedSerialExecutor = TimelineActor.executor.asUnownedSerialExecutor()

    nonisolated
    public var unownedExecutor: UnownedSerialExecutor { Self.sharedUnownedExecutor }
}

private final class TimelineActorSerialExecutor: SerialExecutor {
    let queue = DispatchQueue(label: "TimelineActorQueue")

    func enqueue(_ job: UnownedJob) {
        queue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        return UnownedSerialExecutor(ordinary: self)
    }
}
