//
//  TimelineRecorder.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import GRDB

@TimelineActor
public final class TimelineRecorder {

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
        didSet {
            Task { await loco.appGroup?.save() }
        }
    }

    public func currentItem(includeSamples: Bool = false) -> TimelineItem? {
        do {
            let item = try Database.pool.read {
                try TimelineItem
                    .itemRequest(includeSamples: includeSamples)
                    .filter(Column("deleted") == false && Column("disabled") == false)
                    .order(Column("endDate").desc)
                    .fetchOne($0)
            }

            // update currentItemId if changed
            if let item, item.id != currentItemId {
                self.currentItemId = item.id
            }

            return item

        } catch {
            logger.error(error, subsystem: .database)
        }

        return nil
    }

    public private(set) var latestSampleId: String?

    public func latestSample() -> LocomotionSample? {
        guard let latestSampleId else { return nil }
        return try? Database.pool.read {
            try LocomotionSample.fetchOne($0, id: latestSampleId)
        }
    }

    // MARK: -

    public private(set) var currentLegacyItemId: String? {
        didSet {
            Task { await loco.appGroup?.save() }
        }
    }

    public func currentLegacyItem() -> LegacyItem? {
        guard let currentLegacyItemId else { return nil }
        return try? Database.legacyPool?.read { try LegacyItem.fetchOne($0, id: currentLegacyItemId) }
    }

    public private(set) var latestLegacySampleId: String?

    public var latestLegacySample: LegacySample? {
        guard let latestLegacySampleId else { return nil }
        return try? Database.pool.read {
            try LegacySample.fetchOne($0, id: latestLegacySampleId)
        }
    }

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
                .filter(Column("deleted") == false && Column("disabled") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }
    }

    private func updateCurrentLegacyItemId() {
        currentLegacyItemId = try? Database.legacyPool?.read {
            try LegacyItem
                .filter(Column("deleted") == false && Column("disabled") == false)
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
                Task { await TimelineProcessor.processFrom(itemId: currentItemId) }
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

    var canStartSleeping: Bool {
        get async {
            guard let currentItem = await currentItem() else {
                return false
            }
            guard currentItem.isVisit else {
                return false
            }
            do {
                return try currentItem.isWorthKeeping
            } catch {
                logger.error(error, subsystem: .timeline)
                return false
            }
        }
    }

    // MARK: -

    private var lastRecordSampleCall: Date?

    private func recordSample() async {
        guard isRecording else { return }

        // minimum 1 second between samples plz
        if let lastRecordSampleCall, lastRecordSampleCall.age < 1 { return }
        lastRecordSampleCall = .now

        var sample = await loco.createASample()

        do {
            try await Database.pool.write { [sample] in
                try sample.save($0)
            }
            
            await processSample(&sample)
            await sample.saveRTree()

        } catch {
            logger.error(error, subsystem: .database)
        }

        latestSampleId = sample.id
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

        // minimum 1 second between samples plz
        if let lastRecordSampleCall, lastRecordSampleCall.age < 1 { return }
        lastRecordSampleCall = .now

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

        latestLegacySampleId = sample.id
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
