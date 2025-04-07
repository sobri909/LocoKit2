//
//  TimelineRecorder.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import GRDB

@TimelineActor
public enum TimelineRecorder {

    public static var legacyDbMode = false

    public static func startup() {
        Database.pool.add(transactionObserver: TimelineObserver.highlander)
    }

    public static func startRecording() {
        startWatchingLoco()
        Task {
            await loco.startRecording()
            await startFallbackSampleTimer()
        }
    }

    public static func stopRecording() async {
        await loco.stopRecording()
        await stopFallbackSampleTimer()
    }

    public static var isRecording: Bool {
        get async {
            return await loco.recordingState != .off
        }
    }

    // MARK: -

    public static private(set) var currentItemId: String? {
        didSet {
            Task { await loco.appGroup?.save() }
        }
    }

    public static func currentItem(includeSamples: Bool = false, includePlaces: Bool = false) -> TimelineItem? {
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

    public static private(set) var latestSampleId: String?

    public static func latestSample() -> LocomotionSample? {
        guard let latestSampleId else { return nil }
        return try? Database.pool.read {
            try LocomotionSample.fetchOne($0, id: latestSampleId)
        }
    }

    // MARK: -

    public static private(set) var currentLegacyItemId: String? {
        didSet {
            Task { await loco.appGroup?.save() }
        }
    }

    public static func currentLegacyItem() -> LegacyItem? {
        guard let currentLegacyItemId else { return nil }
        return try? Database.legacyPool?.read { try LegacyItem.fetchOne($0, id: currentLegacyItemId) }
    }

    public static private(set) var latestLegacySampleId: String?

    public static var latestLegacySample: LegacySample? {
        guard let latestLegacySampleId else { return nil }
        return try? Database.pool.read {
            try LegacySample.fetchOne($0, id: latestLegacySampleId)
        }
    }

    // MARK: - Private

    private static let loco = LocomotionManager.highlander

    private static var watchingLoco = false

    private static func startWatchingLoco() {
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

    public static func updateCurrentItemId() {
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

    private static func updateCurrentLegacyItemId() {
        currentLegacyItemId = try? Database.legacyPool?.read {
            try LegacyItem
                .filter(Column("deleted") == false && Column("disabled") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }
    }

    private static var previousRecordingState: RecordingState?
    private static var recordingEnded: Date?

    // MARK: -

    private static func recordingStateChanged(_ recordingState: RecordingState) async {
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

            // force a sample at state transition, to ensure currentVisit is a keeper
            // (transition to sleep only requires up-to-now duration, and distance filtered
            // location updates mean actual dateRange may not reflect that, preventing
            // merges with previous items at same location)
            await recordSample()

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

    private static func updateSleepCycleDuration(_ recordingState: RecordingState) async {
        // ensure sleep cycles are short for when sleeping next starts
        if recordingState == .recording {
            await loco.setSleepCycleDuration(6)
            return
        }

        guard let currentItem = currentItem(includePlaces: true),
              let place = currentItem.place,
              let dateRange = currentItem.dateRange else {
            await updateSleepCycleDurationFallback()
            return
        }

        // Calculate combined probability
        let visitDuration = -dateRange.start.timeIntervalSinceNow
        guard let probability = place.leavingProbabilityFor(duration: visitDuration) else {
            await updateSleepCycleDurationFallback()
            return
        }

        // Map probability to duration (6-60 seconds)
        let shortCycleThreshold = 0.2 // probability threshold for 6s sleep cycles

        switch probability {
        case shortCycleThreshold...1.0:  // high probability
            await loco.setSleepCycleDuration(6)

        case 0.01..<shortCycleThreshold: // common probability range
            let normalised = (probability - 0.01) / (shortCycleThreshold - 0.01)
            // Use cube root (0.33) for aggressive curve towards shorter cycles
            let curved = pow(normalised, 0.33)
            await loco.setSleepCycleDuration(60 - (curved * 54))

        default:         // Very low probability (<1%)
            await loco.setSleepCycleDuration(60)
        }
    }

    private static func updateSleepCycleDurationFallback() async {
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

    static var canStartSleeping: Bool {
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

    // MARK: - Sample recording

    private static var lastRecordSampleCall: Date?

    private static func recordSample() async {
        guard await isRecording else { return }

        // minimum 1 second between samples plz
        if let lastRecordSampleCall, lastRecordSampleCall.age < 1 { return }
        lastRecordSampleCall = .now

        let sample = await loco.createASample()

        do {
            try await Database.pool.write { [sample] in
                try sample.insert($0)
            }
            
            await processSample(sample)

            // reset the fallback
            await startFallbackSampleTimer()

        } catch {
            logger.error(error, subsystem: .database)
        }

        latestSampleId = sample.id
    }

    private static func processSample(_ sample: LocomotionSample) async {

        /** first timeline item **/
        guard let workingItem = currentItem() else {
            let newItemBase = await createTimelineItem(from: sample)
            currentItemId = newItemBase.id
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != .stationary

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItemBase = await createTimelineItem(from: sample, previousItemId: workingItem.id)
            currentItemId = newItemBase.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        do {
            try await Database.pool.write { [sample] in
                var mutableSample = sample
                try mutableSample.updateChanges($0) {
                    $0.timelineItemId = workingItem.id
                }
            }
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    private static func createTimelineItem(from sample: LocomotionSample, previousItemId: String? = nil) async -> TimelineItemBase {
        var newItem = TimelineItemBase(from: sample)

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

        do {
            try await Database.pool.write { [newItem, sample] in
                try newItem.insert($0)
                try newVisit?.insert($0)
                try newTrip?.insert($0)
                var mutableSample = sample
                try mutableSample.updateChanges($0) {
                    $0.timelineItemId = newItem.id
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }

        return newItem
    }

    // MARK: - Fallback sample recording

    @MainActor
    private static let fallbackSampleDuration: TimeInterval = 60

    @MainActor
    private static var fallbackSampleTimer: Timer?

    @MainActor
    private static func startFallbackSampleTimer() {
        fallbackSampleTimer?.invalidate()
        fallbackSampleTimer = Timer.scheduledTimer(withTimeInterval: fallbackSampleDuration, repeats: false) { _ in
            Task {
                // only record if we haven't had a sample in a while
                if let latestSample = await Self.latestSample(),
                   await latestSample.date.age > Self.loco.fallbackUpdateDuration {
                    await Self.recordSample()
                }
                await Self.startFallbackSampleTimer()
            }
        }
    }

    @MainActor
    private static func stopFallbackSampleTimer() {
        fallbackSampleTimer?.invalidate()
        fallbackSampleTimer = nil
    }

    // MARK: - Legacy db recording

    private static func recordLegacySample() async {
        guard await isRecording else { return }

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

    private static func processLegacySample(_ sample: inout LegacySample) async {

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

    private static func createLegacyTimelineItem(from sample: inout LegacySample, previousItemId: String? = nil) async -> LegacyItem {
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
