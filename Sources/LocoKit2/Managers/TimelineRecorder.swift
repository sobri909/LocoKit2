//
//  TimelineRecorder.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import Combine
import GRDB

@Observable
public final class TimelineRecorder {

    public static let highlander = TimelineRecorder()

    // MARK: - Public

    public var legacyDbMode = false

    public func startRecording() {
        loco.startRecording()
    }

    public func stopRecording() {
        loco.stopRecording()
    }

    public var isRecording: Bool {
        return loco.recordingState != .off
    }

    // MARK: -

    public private(set) var currentItemId: String?

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

    public private(set) var currentLegacyItemId: String?

    public func currentLegacyItem() -> LegacyItem? {
        guard let currentLegacyItemId else { return nil }
        return try? Database.legacyPool?.read { try LegacyItem.fetchOne($0, id: currentLegacyItemId) }
    }

    public private(set) var latestLegacySample: LegacySample?

    // MARK: - Private

    private var loco = LocomotionManager.highlander

    private init() {
        if self.legacyDbMode {
            updateCurrentItemId()
        } else {
            updateCurrentLegacyItemId()
        }

        withContinousObservation(of: self.loco.lastUpdated) { _ in
            Task {
                if self.legacyDbMode {
                    await self.recordLegacySample()
                } else {
                    await self.recordSample()
                }
            }
        }

        withContinousObservation(of: self.loco.recordingState) { _ in
            self.recordingStateChanged()
        }
    }

    public func updateCurrentItemId() {
        currentItemId = try? Database.pool.read {
            try TimelineItemBase
                .filter(Column("deleted") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }
    }

    public func updateCurrentLegacyItemId() {
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

    private func recordingStateChanged() {
        // we're only here for changes
        if loco.recordingState == previousRecordingState {
            return
        }

        // keep track of sleep start
        if loco.recordingState == .recording {
            recordingEnded = nil
        } else if previousRecordingState == .recording {
            recordingEnded = .now
        }

        previousRecordingState = loco.recordingState

        switch loco.recordingState {
        case .sleeping, .recording:
            updateSleepCycleDuration()
            break
        default:
            break
        }
    }

    private func updateSleepCycleDuration() {
        // ensure sleep cycles are short for when sleeping next starts
        if loco.recordingState == .recording {
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

        let sample = await loco.createASample()

        do {
            try await Database.pool.write {
                try sample.save($0)
            }
            
            await processSample(sample)

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        await MainActor.run {
            latestSample = sample
        }
    }

    private func processSample(_ sample: LocomotionSample) async {

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
        sample.timelineItemId = workingItem.id

        do {
            try await Database.pool.write {
                _ = try sample.updateChanges($0)
            }
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func createTimelineItem(from sample: LocomotionSample, previousItemId: String? = nil) async -> TimelineItemBase {
        let newItem = TimelineItemBase(from: sample)

        // assign the sample
        sample.timelineItemId = newItem.id

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
            try await Database.pool.write {
                try newItem.save($0)
                try newVisit?.save($0)
                try newTrip?.save($0)
                _ = try sample.updateChanges($0)
            }

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        return newItem
    }

    // MARK: - Legacy db recording

    private func recordLegacySample() async {
        guard isRecording else { return }

        let sample = await loco.createALegacySample()

        do {
            try await Database.legacyPool?.write {
                try sample.save($0)
            }

            await processLegacySample(sample)

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        await MainActor.run {
            latestLegacySample = sample
        }
    }

    private func processLegacySample(_ sample: LegacySample) async {

        /** first timeline item **/
        guard let workingItem = currentLegacyItem() else {
            let newItem = await createLegacyTimelineItem(from: sample)
            currentLegacyItemId = newItem.id
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != "stationary"

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItem = await createLegacyTimelineItem(from: sample, previousItemId: workingItem.id)
            currentLegacyItemId = newItem.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        do {
            try await Database.legacyPool?.write {
                _ = try sample.updateChanges($0)
            }
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func createLegacyTimelineItem(from sample: LegacySample, previousItemId: String? = nil) async -> LegacyItem {
        let newItem = LegacyItem(from: sample)

        // assign the sample
        sample.timelineItemId = newItem.id

        // keep the list linked
        newItem.previousItemId = previousItemId

        do {
            try await Database.legacyPool?.write {
                try newItem.save($0)
                _ = try sample.updateChanges($0)
            }

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        return newItem
    }

}
