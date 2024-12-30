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

    public func currentItem(includeSamples: Bool = false, includePlaces: Bool = false) -> TimelineItem? {
        do {
            let item = try Database.pool.read {
                try TimelineItem
                    .itemRequest(includeSamples: includeSamples, includePlaces: includePlaces)
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
                await recordingStateChanged(newState)
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

    private func recordingStateChanged(_ recordingState: RecordingState) async {
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
            await updateSleepCycleDuration(recordingState)
            break
        default:
            break
        }
    }

    private func updateSleepCycleDuration(_ recordingState: RecordingState) async {
        // ensure sleep cycles are short for when sleeping next starts
        if recordingState == .recording {
            await loco.setSleepCycleDuration(6)
            return
        }

        guard let currentItem = currentItem(),
              let place = currentItem.place,
              let dateRange = currentItem.dateRange else {
            await updateSleepCycleDurationFallback()
            return
        }

        // Calculate combined probability
        let visitDuration = -dateRange.start.timeIntervalSinceNow
        guard let probability = place.calculateLeavingProbability(visitDuration: visitDuration) else {
            await updateSleepCycleDurationFallback()
            return
        }

        if TimelineProcessor.debugLogging {
            print("""
                Sleep cycle probability:
                - Place: \(place.name)
                - Visit duration: \(visitDuration / 60) mins
                - Combined probability: \(String(format: "%.3f", probability))
                """)
        }

        // Map probability to duration (6-60 seconds)
        switch probability {
        case 0.5...1.0:  // High probability (>50%)
            await loco.setSleepCycleDuration(6)
        case 0.01..<0.5: // Scale between 1-50%
            let normalized = (probability - 0.01) / 0.49
            await loco.setSleepCycleDuration(60 - (normalized * 54))
        default:         // Very low probability (<1%)
            await loco.setSleepCycleDuration(60)
        }
    }

    private func updateSleepCycleDurationFallback() async {
        guard let recordingEnded else {
            await loco.setSleepCycleDuration(6)
            return
        }

        let sleepMinutes = recordingEnded.age / 60
        if sleepMinutes < 2 {
            await loco.setSleepCycleDuration(6)
        } else if sleepMinutes <= 60 {
            await loco.setSleepCycleDuration(6 + ((sleepMinutes - 2) / 58 * (60 - 6)))
        } else {
            await loco.setSleepCycleDuration(60)
        }
    }

    var canStartSleeping: Bool {
        get async {
            guard let currentItem = currentItem() else {
                return false
            }
            guard currentItem.isVisit else {
                return false
            }
            guard let dateRange = currentItem.dateRange else {
                return false
            }
            // use age instead of duration, because distanceFilter delays new samples when stationary
            return dateRange.start.age >= TimelineItemVisit.minimumKeeperDuration
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
