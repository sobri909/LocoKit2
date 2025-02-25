//
//  TasksManager.swift
//
//  Created on 2025-02-25.
//

import Foundation
import BackgroundTasks

@MainActor
public final class TasksManager {

    public static let highlander = TasksManager()

    enum TaskState: String, Codable, CaseIterable {
        case running, expired, unfinished, completed, scheduled, registered
    }
    
    struct TaskStatus: Codable, Identifiable {
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
    private var taskStatuses: [String: TaskStatus] = [:]
    private var taskDefinitions: [String: TaskDefinition] = [:]
    
    init() {
        loadTaskStatuses()
    }
    
    // MARK: - Task Management
    
    public func add(task: TaskDefinition) {
        taskDefinitions[task.identifier] = task
        registerTask(identifier: task.identifier)
        updateTaskState(task.identifier, state: .registered)
    }

    public func scheduleTasks() {
        for identifier in taskDefinitions.keys {
            scheduleTask(identifier: identifier)
        }
    }

    // MARK: - Private

    private func registerTask(identifier: String) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [weak self] task in
            guard let self, let processingTask = task as? BGProcessingTask else { return }
            
            Task { @MainActor in
                try await self.handleTask(identifier: identifier, task: processingTask)
            }
        }
    }

    private func scheduleTask(identifier: String) {
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
        } else {
            // if never run before, schedule after minimum delay
            request.earliestBeginDate = Date(timeIntervalSinceNow: minimumDelay / 2)
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
    
    private func handleTask(identifier: String, task: BGProcessingTask) async throws {
        guard let taskDefinition = taskDefinitions[identifier] else {
            task.setTaskCompleted(success: false)
            return
        }
        
        updateTaskState(identifier, state: .running)
        
        // create a task for the actual processing
        let workTask = Task {
            try await taskDefinition.workHandler()
        }
        
        // handle expiration
        task.expirationHandler = { [weak self] in
            workTask.cancel()
            self?.updateTaskState(identifier, state: .expired)
            task.setTaskCompleted(success: false)
        }
        
        // do the work
        do {
            try await workTask.value
            updateTaskState(identifier, state: .completed)
            scheduleTask(identifier: identifier)
            task.setTaskCompleted(success: true)
            
        } catch {
            updateTaskState(identifier, state: .unfinished)
            scheduleTask(identifier: identifier)
            task.setTaskCompleted(success: false)
            logger.error(error, subsystem: .tasks)
        }
    }
    
    private func updateTaskState(_ identifier: String, state: TaskState) {
        guard let taskDefinition = taskDefinitions[identifier] else { return }
        
        var status = taskStatuses[identifier] ?? TaskStatus(
            identifier: identifier,
            state: state,
            minimumDelay: taskDefinition.minimumDelay,
            lastUpdated: .now
        )
        
        status.state = state
        status.lastUpdated = .now
        
        // extract task name from identifier (last part after the final dot)
        let taskName = identifier.split(separator: ".").last ?? identifier

        if state == .unfinished {
            logger.error("\(state.rawValue): \(taskName)", subsystem: .tasks)
        } else {
            logger.info("\(state.rawValue): \(taskName)", subsystem: .tasks)
        }

        switch state {
        case .running:
            status.lastStarted = .now
        case .expired:
            status.lastExpired = .now
        case .completed:
            status.lastCompleted = .now
        }
        
        taskStatuses[identifier] = status
        saveTaskStatuses()
    }
    
    // MARK: - Persistence
    
    private func loadTaskStatuses() {
        if let data = UserDefaults.standard.data(forKey: "taskStatuses"),
           let statuses = try? JSONDecoder().decode([String: TaskStatus].self, from: data) {
            taskStatuses = statuses
        }
    }
    
    private func saveTaskStatuses() {
        if let data = try? JSONEncoder().encode(taskStatuses) {
            UserDefaults.standard.set(data, forKey: "taskStatuses")
        }
    }
}
