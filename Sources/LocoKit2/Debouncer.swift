//
//  Debouncer.swift
//
//  Created by Matt Greenfield on 26/10/23.
//

import Foundation

final class Debouncer: Sendable {
    private let worker = Worker()

    func debounce(duration: TimeInterval, force forceInterval: TimeInterval = .infinity, _ action: @escaping @Sendable () async -> Void) {
        Task { await worker.debounce(duration: duration, force: forceInterval, action) }
    }

    func cancel() {
        Task { await worker.cancel() }
    }

    private actor Worker {
        private var currentTask: Task<Void, Error>?
        private var lastUpdateTime: Date?

        deinit {
            currentTask?.cancel()
        }

        func cancel() {
            currentTask?.cancel()
        }

        func debounce(duration: TimeInterval, force forceInterval: TimeInterval = .infinity, _ action: @escaping @Sendable () async -> Void) {
            // Cancel any existing task
            currentTask?.cancel()

            // Create a single new task that handles both force and normal cases
            currentTask = Task {
                if let lastUpdate = lastUpdateTime, lastUpdate.age > forceInterval {
                    // Force case: update time but still use Task for execution
                    lastUpdateTime = .now
                    await action()
                } else {
                    // Normal case: wait then execute
                    try await Task.sleep(for: .seconds(duration))
                    lastUpdateTime = .now
                    await action()
                }
            }
        }
    }
}
