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
        updateTaskStateFor(identifier: task.identifier, to: .registered)
    }

    public static func scheduleTasks() {
        for identifier in taskDefinitions.keys {
            scheduleTask(identifier: identifier)
        }
    }

    // MARK: - Private

    private static func registerTask(identifier: String) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleTask(identifier: identifier, task: processingTask)
        }
    }

    private static func scheduleTask(identifier: String) {
        guard let taskDefinition = taskDefinitions[identifier] else { return }
        
        let request = BGProcessingTaskRequest(identifier: identifier)
        
        // determine earliest begin date based on last execution
        let status = try? getTaskStatusFor(identifier: identifier)
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
            updateTaskStateFor(identifier: identifier, to: .scheduled)
        } catch {
            Log.error(error, subsystem: .tasks)
        }
    }

    private static func handleTask(identifier: String, task: BGProcessingTask) {
        guard let taskDefinition = taskDefinitions[identifier] else {
            task.setTaskCompleted(success: false)
            return
        }
        
        updateTaskStateFor(identifier: identifier, to: .running)

        let workTask = Task.detached {
            do {
                try await taskDefinition.workHandler()

                await MainActor.run {
                    updateTaskStateFor(identifier: identifier, to: .completed)
                    scheduleTask(identifier: identifier)
                    task.setTaskCompleted(success: true)
                }

            } catch {
                await MainActor.run {
                    updateTaskStateFor(identifier: identifier, to: .unfinished)
                    scheduleTask(identifier: identifier)
                    task.setTaskCompleted(success: false)
                    Log.error(error, subsystem: .tasks)
                }
            }
        }

        task.expirationHandler = {
            workTask.cancel()
            Task { @MainActor in
                updateTaskStateFor(identifier: identifier, to: .expired)
                task.setTaskCompleted(success: false)
            }
        }
    }

    // MARK: - TaskStatus handling

    private static func getTaskStatusFor(identifier: String) throws -> TaskStatus? {
        return try Database.pool.read {
            try TaskStatus.fetchOne($0, key: identifier)
        }
    }

    private static func updateTaskStateFor(identifier: String, to state: TaskStatus.TaskState) {
        guard let taskDefinition = taskDefinitions[identifier] else { return }

        do {
            guard let status = try getTaskStatusFor(identifier: identifier) else {
                // no existing TaskStatus, so create and save a new one
                var status = TaskStatus(
                    identifier: identifier,
                    state: state,
                    minimumDelay: taskDefinition.minimumDelay,
                    lastUpdated: .now
                )
                update(taskStatus: &status, state: state)
                try Database.pool.write {
                    try status.insert($0)
                }
                return
            }

            try Database.pool.write { db in
                var mutableStatus = status
                try mutableStatus.updateChanges(db) { status in
                    update(taskStatus: &status, state: state)
                }
            }

        } catch {
            Log.error(error, subsystem: .tasks)
        }
    }

    private static func update(taskStatus status: inout TaskStatus, state: TaskStatus.TaskState) {
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
