//
//  TasksManager.swift
//
//  Created on 2025-02-25.
//

import Foundation
@preconcurrency
import BackgroundTasks

@MainActor
public enum TasksManager {

    enum TaskState: String, Codable, CaseIterable, Sendable {
        case running, expired, unfinished, completed, scheduled, registered
    }
    
    struct TaskStatus: Codable, Identifiable, Sendable {
        var identifier: String
        var state: TaskState
        var minimumDelay: TimeInterval
        var lastUpdated: Date
        var lastStarted: Date?
        var lastExpired: Date?
        var lastCompleted: Date?
        var id: String { return identifier }
        var overdueBy: TimeInterval {
            guard let lastCompleted else { return 0 }
            return lastCompleted.age - minimumDelay
        }
    }
    
    // status tracking
    
    init() {
        loadTaskStatuses()
    }
    static var taskStatuses: [String: TaskStatus] = [:]
    static var taskDefinitions: [String: TaskDefinition] = [:]
    
    // MARK: - Task Management
    
    public static func add(task: TaskDefinition) {
        taskDefinitions[task.identifier] = task
        registerTask(identifier: task.identifier)
        updateTaskState(task.identifier, state: .registered)
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
        let status = taskStatuses[identifier]
        let minimumDelay = taskDefinition.minimumDelay
        
        if let lastCompleted = status?.lastCompleted {
            // calculate next run time based on last completion and minimum delay
            let nextRunTime = lastCompleted.addingTimeInterval(minimumDelay)
            if nextRunTime > .now {
                request.earliestBeginDate = nextRunTime
            }

        } else { // if never completed before, schedule after minimum delay
            request.earliestBeginDate = Date(timeIntervalSinceNow: minimumDelay)
        }
        
        request.requiresNetworkConnectivity = taskDefinition.requiresNetwork
        request.requiresExternalPower = taskDefinition.requiresPower
        
        do {
            try BGTaskScheduler.shared.submit(request)
            updateTaskState(identifier, state: .scheduled)
        } catch {
            logger.error("Could not schedule: \(error.localizedDescription)", subsystem: .tasks)
        }
    }

    private static func handleTask(identifier: String, task: BGProcessingTask) {
        guard let taskDefinition = taskDefinitions[identifier] else {
            task.setTaskCompleted(success: false)
            return
        }
        
        updateTaskState(identifier, state: .running)

        // Create detached task for the heavy work
        let workTask = Task.detached { [self] in
            do {
                try await taskDefinition.workHandler()

                // Jump back to main actor for state updates
                await MainActor.run {
                    self.updateTaskState(identifier, state: .completed)
                    self.scheduleTask(identifier: identifier)
                    task.setTaskCompleted(success: true)
                }
            } catch {
                await MainActor.run {
                    self.updateTaskState(identifier, state: .unfinished)
                    self.scheduleTask(identifier: identifier)
                    task.setTaskCompleted(success: false)
                    logger.error(error, subsystem: .tasks)
                }
            }
        }

        task.expirationHandler = {
            workTask.cancel()
            Task { @MainActor in
                self.updateTaskState(identifier, state: .expired)
                task.setTaskCompleted(success: false)
            }
        }
    }

    private static func updateTaskState(_ identifier: String, state: TaskState) {
        guard let taskDefinition = taskDefinitions[identifier] else { return }
        
        var status = taskStatuses[identifier] ?? TaskStatus(
            identifier: identifier,
            state: state,
            minimumDelay: taskDefinition.minimumDelay,
            lastUpdated: .now
        )
        
        status.state = state
        status.lastUpdated = .now
        
        let taskName = identifier.split(separator: ".").last.map(String.init) ?? identifier

        if state == .unfinished {
            logger.error("\(state.rawValue): \(taskName)", subsystem: .tasks)
        } else {
            logger.info("\(state.rawValue): \(taskName)", subsystem: .tasks)
        }

        switch state {
        case .running, .expired, .completed:
            status.lastStarted = .now
        default:
            break
        }
        
        taskStatuses[identifier] = status
        saveTaskStatuses()
    }
    
    // MARK: - Persistence
    
    private static func loadTaskStatuses() {
        if let data = UserDefaults.standard.data(forKey: "taskStatuses"),
           let statuses = try? JSONDecoder().decode([String: TaskStatus].self, from: data) {
            taskStatuses = statuses
        }
    }
    
    private static func saveTaskStatuses() {
        if let data = try? JSONEncoder().encode(taskStatuses) {
            UserDefaults.standard.set(data, forKey: "taskStatuses")
        }
    }
}
