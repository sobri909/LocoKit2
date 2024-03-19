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

    public func startRecording() {
        loco.startRecording()
    }

    public func stopRecording() {
        loco.stopRecording()
    }

    public var isRecording: Bool {
        return loco.recordingState != .off
    }

    // TODO: bootstrap this on startup
    public private(set) var currentItemId: String?

    public func currentItem() -> TimelineItemBase? {
        guard let currentItemId else { return nil }
        return try? Database.pool.read { try TimelineItemBase.fetchOne($0, id: currentItemId) }
    }

    // MARK: - Private

    private var loco = LocomotionManager.highlander

    @ObservationIgnored
    private var observers: Set<AnyCancellable> = []

    private init() {
        withContinousObservation(of: LocomotionManager.highlander.filteredLocations) { _ in
            Task { await self.recordSample() }
        }
    }

    // MARK: -

    private func recordSample() async {
        guard isRecording else { return }

        guard let location = loco.filteredLocations.last else { return }
        guard let movingState = loco.currentMovingState else { return }

        let sample = LocomotionSample(
            date: location.timestamp, 
            movingState: movingState.movingState,
            recordingState: loco.recordingState,
            location: location
        )

        do {
            try await Database.pool.write {
                try sample.save($0)
            }

            await process(sample)

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func process(_ sample: LocomotionSample) async {

        /** first timeline item **/
        guard let workingItem = currentItem() else {
            let newItem = await createTimelineItem(from: sample)
            currentItemId = newItem.id
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != .stationary

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItem = await createTimelineItem(from: sample, previousItemId: workingItem.id)
            currentItemId = newItem.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        print("added sample to currentItem")

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

        do {
            try await Database.pool.write {
                try newItem.save($0)
                _ = try sample.updateChanges($0)
            }

            print("createTimelineItem() isVisit: \(newItem.isVisit)")

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        return newItem
    }

}
