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
            if let lastUpdate = lastUpdateTime, lastUpdate.age > forceInterval {
                lastUpdateTime = .now
                currentTask?.cancel()
                currentTask = Task { await action() }
                return
            }

            // Otherwise normal debounce behavior
            currentTask?.cancel()
            currentTask = Task {
                try await Task.sleep(for: .seconds(duration))
                lastUpdateTime = .now
                await action()
            }
        }
    }
}
