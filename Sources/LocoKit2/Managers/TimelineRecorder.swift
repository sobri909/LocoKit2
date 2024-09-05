//
//  TimelineRecorder.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import GRDB

public final class TimelineRecorder: @unchecked Sendable {

    public static let highlander = TimelineRecorder()

    // MARK: - Public

    public var legacyDbMode = false

    public func startRecording() {
        startWatchingLoco()
        loco.startRecording()
    }

    public func stopRecording() {
        loco.stopRecording()
    }

    public var isRecording: Bool {
        return loco.recordingState != .off
    }

    // MARK: -

    public private(set) var currentItemId: String? {
        didSet { loco.appGroup?.save() }
    }

    public func currentItem() -> TimelineItem? {
        guard let currentItemId else { return nil }
        return try? Database.pool.read {
            let request = TimelineItemBase
                .including(optional: TimelineItemBase.visit)
                .including(optional: TimelineItemBase.trip)
                .filter(Column("id") == currentItemId)
            return try TimelineItem.fetchOne($0, request)
        }
    }

    public private(set) var latestSample: LocomotionSample?

    // MARK: -

    public private(set) var currentLegacyItemId: String? {
        didSet { loco.appGroup?.save() }
    }

    public func currentLegacyItem() -> LegacyItem? {
        guard let currentLegacyItemId else { return nil }
        return try? Database.legacyPool?.read { try LegacyItem.fetchOne($0, id: currentLegacyItemId) }
    }

    public private(set) var latestLegacySample: LegacySample?

    // MARK: - Private

    private init() {
        Database.pool.add(transactionObserver: TimelineObserver.highlander)
    }

    private let loco = LocomotionManager.highlander

    private var watchingLoco = false

    private func startWatchingLoco() {
        if watchingLoco { return }
        watchingLoco = true
        
        print("startWatchingLoco()")

        updateCurrentItemId()

        Task {
            for await _ in loco.locationUpdates() {
                if legacyDbMode {
                    await recordLegacySample()
                } else {
                    await recordSample()
                }
            }
        }

        Task {
            for await newState in loco.stateUpdates() {
                recordingStateChanged(newState)
            }
        }
    }

    public func updateCurrentItemId() {
        if legacyDbMode {
            updateCurrentLegacyItemId()
            return
        }

        currentItemId = try? Database.pool.read {
            try TimelineItemBase
                .filter(Column("deleted") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }
    }

    private func updateCurrentLegacyItemId() {
        currentLegacyItemId = try? Database.legacyPool?.read {
            try LegacyItem
                .filter(Column("deleted") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }
    }

    private var previousRecordingState: RecordingState?
    private var recordingEnded: Date?

    // MARK: -

    private func recordingStateChanged(_ recordingState: RecordingState) {
        // we're only here for changes
        if recordingState == previousRecordingState {
            return
        }

        // keep track of sleep start
        if recordingState == .recording {
            recordingEnded = nil
        } else if previousRecordingState == .recording {
            recordingEnded = .now
        }

        // fire up the processor on transition to sleep
        if previousRecordingState == .recording, recordingState == .sleeping {
            print("recordingStateChanged() .recording -> .sleeping")
            if let currentItemId {
                Task { await TimelineProcessor.highlander.processFrom(itemId: currentItemId) }
            }
        }

        previousRecordingState = recordingState

        switch recordingState {
        case .sleeping, .recording:
            updateSleepCycleDuration(recordingState)
            break
        default:
            break
        }
    }

    private func updateSleepCycleDuration(_ recordingState: RecordingState) {
        // ensure sleep cycles are short for when sleeping next starts
        if recordingState == .recording {
            loco.sleepCycleDuration = 6
            return
        }

        guard let sleepDuration = recordingEnded?.age else {
            loco.sleepCycleDuration = 6
            return
        }

        let sleepMinutes = sleepDuration / 60

        if sleepMinutes < 2 {
            loco.sleepCycleDuration = 6
        } else if sleepMinutes <= 60 {
            loco.sleepCycleDuration = 6 + ((sleepMinutes - 2) / 58 * (60 - 6))
        } else {
            loco.sleepCycleDuration = 60
        }
    }

    // MARK: -

    private func recordSample() async {
        guard isRecording else { return }

        var sample = await loco.createASample()

        do {
            let sampleCopy = sample
            try await Database.pool.write {
                try sampleCopy.save($0)
            }
            
            await processSample(&sample)
            await sample.saveRTree()

        } catch {
            logger.error(error, subsystem: .database)
        }

        let sampleCopy = sample
        await MainActor.run {
            latestSample = sampleCopy
        }
    }

    private func processSample(_ sample: inout LocomotionSample) async {

        /** first timeline item **/
        guard let workingItem = currentItem() else {
            let newItemBase = await createTimelineItem(from: &sample)
            currentItemId = newItemBase.id
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != .stationary

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItemBase = await createTimelineItem(from: &sample, previousItemId: workingItem.id)
            currentItemId = newItemBase.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        do {
            let sampleCopy = sample
            try await Database.pool.write {
                try sampleCopy.save($0)
            }
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    private func createTimelineItem(from sample: inout LocomotionSample, previousItemId: String? = nil) async -> TimelineItemBase {
        var newItem = TimelineItemBase(from: &sample)

        // keep the list linked
        newItem.previousItemId = previousItemId

        let newVisit: TimelineItemVisit?
        let newTrip: TimelineItemTrip?
        
        if newItem.isVisit {
            newVisit = TimelineItemVisit(itemId: newItem.id, samples: [sample])
            newTrip = nil
        } else {
            newTrip = TimelineItemTrip(itemId: newItem.id, samples: [sample])
            newVisit = nil
        }

        let itemCopy = newItem
        let sampleCopy = sample
        do {
            try await Database.pool.write {
                try itemCopy.save($0)
                try newVisit?.save($0)
                try newTrip?.save($0)
                try sampleCopy.save($0)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }

        return newItem
    }

    // MARK: - Legacy db recording

    private func recordLegacySample() async {
        guard isRecording else { return }

        var sample = await loco.createALegacySample()

        do {
            let sampleCopy = sample
            try await Database.legacyPool?.write {
                try sampleCopy.save($0)
            }

            await processLegacySample(&sample)

        } catch {
            logger.error(error, subsystem: .database)
        }

        let sampleCopy = sample
        await MainActor.run {
            latestLegacySample = sampleCopy
        }
    }

    private func processLegacySample(_ sample: inout LegacySample) async {

        /** first timeline item **/
        guard let workingItem = currentLegacyItem() else {
            let newItem = await createLegacyTimelineItem(from: &sample)
            currentLegacyItemId = newItem.id
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != "stationary"

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItem = await createLegacyTimelineItem(from: &sample, previousItemId: workingItem.id)
            currentLegacyItemId = newItem.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        do {
            let sampleCopy = sample
            try await Database.legacyPool?.write {
                try sampleCopy.save($0)
            }
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    private func createLegacyTimelineItem(from sample: inout LegacySample, previousItemId: String? = nil) async -> LegacyItem {
        var newItem = LegacyItem(from: sample)

        // assign the sample
        sample.timelineItemId = newItem.id

        // keep the list linked
        newItem.previousItemId = previousItemId

        do {
            let itemCopy = newItem
            let sampleCopy = sample
            try await Database.legacyPool?.write {
                try itemCopy.save($0)
                try sampleCopy.save($0)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }

        return newItem
    }

}
