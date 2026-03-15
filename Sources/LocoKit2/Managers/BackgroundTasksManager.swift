//
//  BackgroundTasksManager.swift
//  LocoKit2
//
//  Created on 2025-02-25.
//

import Foundation
@preconcurrency import BackgroundTasks
import GRDB

@MainActor
public enum BackgroundTasksManager {

    static var taskDefinitions: [String: BackgroundTaskDefinition] = [:]

    // MARK: - Task Management
    
    public static func add(task: BackgroundTaskDefinition) {
        let alreadyRegistered = taskDefinitions[task.identifier] != nil
        taskDefinitions[task.identifier] = task
        if !alreadyRegistered {
            registerTask(identifier: task.identifier)
        }
        Task { await updateTaskStateFor(identifier: task.identifier, to: .registered) }
    }

    public static func scheduleTasks() {
        Task {
            for identifier in taskDefinitions.keys {
                await scheduleTask(identifier: identifier)
            }
        }
    }

    // MARK: - Foreground Overdue Tasks

    public static func hasOverdueForegroundTasks() async -> Bool {
        for (identifier, definition) in taskDefinitions {
            guard let threshold = definition.foregroundThreshold else { continue }
            guard let status = try? await getTaskStatusFor(identifier: identifier) else { continue }
            guard status.state != .running else { continue }
            if status.isForegroundOverdue(threshold: threshold) { return true }
        }
        return false
    }

    public static func runOverdueTasks(onTaskStarted: (@MainActor (String) -> Void)? = nil) async {
        guard LocomotionManager.highlander.recordingState != .recording else { return }
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else { return }

        for (identifier, definition) in taskDefinitions {
            try? Task.checkCancellation()
            guard LocomotionManager.highlander.recordingState != .recording else { break }
            guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else { break }

            guard let threshold = definition.foregroundThreshold else { continue }

            guard let status = try? await getTaskStatusFor(identifier: identifier) else { continue }
            guard status.state != .running else { continue }
            guard status.isForegroundOverdue(threshold: threshold) else { continue }

            Log.info("Running overdue task in foreground: \(status.shortName)", subsystem: .tasks)
            onTaskStarted?(definition.displayName)
            await updateTaskStateFor(identifier: identifier, to: .running)

            do {
                try await definition.workHandler()
                await updateTaskStateFor(identifier: identifier, to: .completed)
                await scheduleTask(identifier: identifier)

            } catch {
                await updateTaskStateFor(identifier: identifier, to: .unfinished)
                await scheduleTask(identifier: identifier)
                Log.error(error, subsystem: .tasks)
            }
        }
    }

    // MARK: - Private

    private static func registerTask(identifier: String) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleTask(identifier: identifier, task: processingTask)
        }
    }

    private static func scheduleTask(identifier: String) async {
        guard let taskDefinition = taskDefinitions[identifier] else { return }

        let request = BGProcessingTaskRequest(identifier: identifier)

        // determine earliest begin date based on last execution
        let status = try? await getTaskStatusFor(identifier: identifier)
        let minimumDelay = taskDefinition.minimumDelay

        if let lastCompleted = status?.lastCompleted {
            // calculate next run time based on last completion and minimum delay
            let nextRunTime = lastCompleted.addingTimeInterval(minimumDelay)
            if nextRunTime > .now {
                request.earliestBeginDate = nextRunTime
            }
            // if nextRunTime <= .now, don't set earliestBeginDate (run ASAP)
        }
        // if never completed before, don't set earliestBeginDate (run ASAP)

        request.requiresNetworkConnectivity = taskDefinition.requiresNetwork
        request.requiresExternalPower = taskDefinition.requiresPower

        do {
            try BGTaskScheduler.shared.submit(request)
            await updateTaskStateFor(identifier: identifier, to: .scheduled)
        } catch {
            Log.error(error, subsystem: .tasks)
        }
    }

    private static func handleTask(identifier: String, task: BGProcessingTask) {
        guard let taskDefinition = taskDefinitions[identifier] else {
            task.setTaskCompleted(success: false)
            return
        }

        // don't run scheduled tasks during active recording
        if LocomotionManager.highlander.recordingState == .recording {
            task.setTaskCompleted(success: true)
            Task { await scheduleTask(identifier: identifier) }
            return
        }

        Task { await updateTaskStateFor(identifier: identifier, to: .running) }

        let workTask = Task.detached {
            do {
                try await taskDefinition.workHandler()

                await MainActor.run {
                    Task {
                        await updateTaskStateFor(identifier: identifier, to: .completed)
                        await scheduleTask(identifier: identifier)
                    }
                    task.setTaskCompleted(success: true)
                }

            } catch {
                await MainActor.run {
                    Task {
                        await updateTaskStateFor(identifier: identifier, to: .unfinished)
                        await scheduleTask(identifier: identifier)
                    }
                    task.setTaskCompleted(success: false)
                    Log.error(error, subsystem: .tasks)
                }
            }
        }

        task.expirationHandler = {
            workTask.cancel()
            Task { @MainActor in
                Task { await updateTaskStateFor(identifier: identifier, to: .expired) }
                task.setTaskCompleted(success: false)
            }
        }
    }

    // MARK: - TaskStatus handling

    private static func getTaskStatusFor(identifier: String) async throws -> TaskStatus? {
        return try await Database.pool.read {
            try TaskStatus.fetchOne($0, key: identifier)
        }
    }

    private static func updateTaskStateFor(identifier: String, to state: TaskStatus.TaskState) async {
        guard let taskDefinition = taskDefinitions[identifier] else { return }

        do {
            guard let status = try await getTaskStatusFor(identifier: identifier) else {
                // no existing TaskStatus, so create and save a new one
                var newStatus = TaskStatus(
                    identifier: identifier,
                    state: state,
                    minimumDelay: taskDefinition.minimumDelay,
                    lastUpdated: .now
                )
                update(taskStatus: &newStatus, state: state)
                let statusToInsert = newStatus
                try await Database.pool.write {
                    try statusToInsert.insert($0)
                }
                return
            }

            let currentState = state
            try await Database.pool.write { [status] db in
                var mutableStatus = status
                try mutableStatus.updateChanges(db) { status in
                    Self.update(taskStatus: &status, state: currentState)
                }
            }

        } catch {
            Log.error(error, subsystem: .tasks)
        }
    }

    nonisolated private static func update(taskStatus status: inout TaskStatus, state: TaskStatus.TaskState) {
        status.state = state
        status.lastUpdated = .now

        switch state {
        case .running:
            status.lastStarted = .now
        case .expired:
            status.lastExpired = .now
        case .completed:
            status.lastCompleted = .now
        default:
            break
        }

        let taskName = status.identifier.split(separator: ".").last.map(String.init) ?? status.identifier
        if state == .unfinished {
            Log.error("\(state.rawValue): \(taskName)", subsystem: .tasks)
        } else if state != .scheduled {
            Log.info("\(state.rawValue): \(taskName)", subsystem: .tasks)
        }
    }

}
