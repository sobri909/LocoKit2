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
    public private(set) var currentItem: TimelineItemBase?

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

        let sampleBase = SampleBase(date: location.timestamp, movingState: movingState.movingState, recordingState: loco.recordingState)
        let sampleLocation = SampleLocation(sampleId: sampleBase.id, location: location)
//        let sampleExtended = SampleExtended(sampleId: sampleBase.id, stepHz: 1)

        do {
            try await Database.pool.write {
                try sampleBase.save($0)
                try sampleLocation.save($0)
//                try sampleExtended.save($0)
            }

            await process(sampleBase)

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func process(_ sample: SampleBase) async {

        /** first timeline item **/
        guard let workingItem = currentItem else {
            currentItem = await createTimelineItem(from: sample)
            return
        }

        let previouslyMoving = !workingItem.isVisit
        let currentlyMoving = sample.movingState != .stationary

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            currentItem = await createTimelineItem(from: sample)
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        do {
            try await Database.pool.write {
                try sample.save($0)
            }
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func createTimelineItem(from sample: SampleBase) async -> TimelineItemBase {
        let newItem = TimelineItemBase(from: sample)

        // add the sample
        sample.timelineItemId = newItem.id

        // keep the list linked
        newItem.previousItemId = currentItem?.id

        do {
            try await Database.pool.write {
                try newItem.save($0)
                try sample.save($0)
            }
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        return newItem
    }

}
