//
//  AppGroupOld.swift
//  Arc
//
//  Created by Matt Greenfield on 28/5/20.
//  Copyright © 2020 Big Paua. All rights reserved.
//

import Foundation
import UIKit

public class AppGroupOld {

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Properties

    public let thisApp: AppGroup.AppName
    public let suiteName: String
    public var timelineRecorder: TimelineRecorder?

    public private(set) var apps: [AppGroup.AppName: AppState] = [:]
    public private(set) var applicationState: UIApplication.State = .background
    public private(set) lazy var groupDefaults: UserDefaults? = { UserDefaults(suiteName: suiteName) }()

    public var sortedApps: [AppState] { apps.values.sorted { $0.updated > $1.updated } }
    public var currentRecorder: AppState? { sortedApps.first { $0.isAliveAndRecording } }
    public var haveMultipleRecorders: Bool { apps.values.filter({ $0.isAliveAndRecording }).count > 1 }
    public var haveAppsInStandby: Bool { apps.values.filter({ $0.recordingState == .standby }).count > 0 }

    private lazy var talker: AppGroupTalk = { AppGroupTalk(messagePrefix: suiteName, appName: thisApp) }()

    // MARK: - Public methods

    public init(appName: AppGroup.AppName, suiteName: String, readOnly: Bool = false) {
        self.thisApp = appName
        self.suiteName = suiteName

        if readOnly { load(); return }

        save()

        let center = NotificationCenter.default
        center.addObserver(forName: .receivedAppGroupMessage, object: nil, queue: nil) { note in
            guard let messageRaw = note.userInfo?["message"] as? String else { return }
            guard let message = AppGroup.Message(rawValue: messageRaw.deletingPrefix(suiteName + ".")) else { return }
            self.received(message)
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] note in
            self?.applicationState = .active
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] note in
            self?.applicationState = .background
        }
    }

    public var shouldBeTheRecorder: Bool {
        // should always be current recorder in foreground
        if applicationState == .active { return true }

        // there's no current recorder? then we should take on the job
        guard let currentRecorder = currentRecorder else { return true }

        // there's multiple recorders, and we're not in foreground? it's time to concede
        if haveMultipleRecorders { return false }

        // if this app is the current recorder, it should continue to be so
        return currentRecorder.appName == thisApp
    }

    public var isAnActiveRecorder: Bool {
        return currentAppState.recordingState.isCurrentRecorder
    }

    public func becameCurrentRecorder() {
        save()
        send(message: .tookOverRecording)
    }

    // MARK: - 

    public func load() {
        var states: [AppGroup.AppName: AppState] = [:]
        for appName in AppGroup.AppName.allCases {
            if let data = groupDefaults?.value(forKey: appName.rawValue) as? Data {
                if let state = try? AppGroupOld.decoder.decode(AppState.self, from: data) {
                    states[appName] = state
                }
            }
        }
        apps = states
    }

    public func save() {
        load()
        apps[thisApp] = currentAppState
        guard let data = try? AppGroupOld.encoder.encode(apps[thisApp]) else { return }
        groupDefaults?.set(data, forKey: thisApp.rawValue)
        send(message: .updatedState)
    }

    var currentAppState: AppGroupOld.AppState {
        if let currentItemId = timelineRecorder?.currentItemId {
            return AppGroupOld.AppState(
                appName: thisApp,
                recordingState: LocomotionManager.highlander.recordingState,
                currentItemId: UUID(uuidString: currentItemId),
                deepSleepingUntil: nil)
        } else {
            return AppGroupOld.AppState(
                appName: thisApp,
                recordingState: LocomotionManager.highlander.recordingState,
                deepSleepingUntil: nil)
        }
    }

    public func notifyObjectChanges(objectIds: Set<UUID>) {
        let messageInfo = AppGroup.MessageInfo(date: Date(), message: .modifiedObjects, appName: thisApp, modifiedObjectIds: objectIds)
        send(message: .modifiedObjects, messageInfo: messageInfo)
    }

    // MARK: - Private

    private func send(message: AppGroup.Message, messageInfo: AppGroup.MessageInfo? = nil) {
        let lastMessage = messageInfo ?? AppGroup.MessageInfo(date: Date(), message: message, appName: thisApp, modifiedObjectIds: nil)
        if let data = try? AppGroupOld.encoder.encode(lastMessage) {
            groupDefaults?.set(data, forKey: "lastMessage")
        }
        talker.send(message)
    }

    private func received(_ message: AppGroup.Message) {
        guard let data = groupDefaults?.value(forKey: "lastMessage") as? Data else { return }
        guard let messageInfo = try? AppGroupOld.decoder.decode(AppGroup.MessageInfo.self, from: data) else { return }
        guard messageInfo.appName != thisApp else { return }
        guard messageInfo.message == message else {
            DebugLogger.logger.debug("LASTMESSAGE.MESSAGE MISMATCH (expected: \(message.rawValue), got: \(messageInfo.message.rawValue))")
            return
        }

        load()

        switch message {
        case .updatedState:
            appStateUpdated(by: messageInfo.appName)
        case .modifiedObjects:
            objectsWereModified(by: messageInfo.appName, messageInfo: messageInfo)
        case .tookOverRecording:
            recordingWasTakenOver(by: messageInfo.appName, messageInfo: messageInfo)
        }
    }
    
    private func appStateUpdated(by: AppGroup.AppName) {
        DebugLogger.logger.debug("RECEIVED: .updatedState, from: \(by.rawValue)")

        guard let currentRecorder else {
            DebugLogger.logger.error("No AppGroupOld.currentRecorder!", subsystem: .appgroup)
            return
        }
        guard let currentItemId = currentRecorder.currentItemId else {
            DebugLogger.logger.error("No AppGroupOld.currentItemId!", subsystem: .appgroup)
            return
        }

        if !isAnActiveRecorder, currentAppState.currentItemId != currentItemId {
            DebugLogger.logger.debug("Local currentItemId is stale (mine: \(self.currentAppState.currentItemId?.uuidString ?? "nil"), theirs: \(currentItemId.uuidString))")
            timelineRecorder?.updateCurrentItemId()
        }
    }

    private func recordingWasTakenOver(by: AppGroup.AppName, messageInfo: AppGroup.MessageInfo) {
        if LocomotionManager.highlander.recordingState.isCurrentRecorder {
            LocomotionManager.highlander.startStandby()
            NotificationCenter.default.post(Notification(name: .concededRecording, object: self, userInfo: nil))
        }
    }

    private func objectsWereModified(by: AppGroup.AppName, messageInfo: AppGroup.MessageInfo) {
        DebugLogger.logger.debug("AppGroupOld received modifiedObjectIds: \(messageInfo.modifiedObjectIds?.count ?? 0) by: \(by.rawValue)")
        if let objectIds = messageInfo.modifiedObjectIds, !objectIds.isEmpty {
            let note = Notification(name: .timelineObjectsExternallyModified, object: self, userInfo: ["modifiedObjectIds": objectIds])
            NotificationCenter.default.post(note)
        }
    }

    // MARK: - Interfaces

    public struct AppState: Codable {
        public let appName: AppGroup.AppName
        public let recordingState: RecordingState
        public var currentItemId: UUID?
        public var currentItemTitle: String?
        public var deepSleepingUntil: Date?
        public var updated = Date()

        public var isAlive: Bool {
            if isDeepSleeping { return true }
            return updated.age < LocomotionManager.highlander.standbyCycleDuration + 3
        }
        public var isAliveAndRecording: Bool { return isAlive && recordingState != .off && recordingState != .standby }
        public var isDeepSleeping: Bool {
            guard let until = deepSleepingUntil else { return false }
            return until.age < 0
        }
    }

}
