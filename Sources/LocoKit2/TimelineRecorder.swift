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

    // MARK: - Private

    private var loco = LocomotionManager.highlander

    @ObservationIgnored
    private var observers: Set<AnyCancellable> = []

    private init() {
        self.currentItemId = try? Database.pool.read {
            try TimelineItemBase
                .filter(Column("deleted") == false)
                .order(Column("endDate").desc)
                .selectPrimaryKey()
                .fetchOne($0)
        }

        withContinousObservation(of: LocomotionManager.highlander.filteredLocations) { _ in
            Task { await self.recordSample() }
        }
    }

    // MARK: -

    private func recordSample() async {
        guard isRecording else { return }

        guard let location = loco.filteredLocations.last else { return }
        guard let movingState = loco.movingStateDetails else { return }

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
            let newItemBase = await createTimelineItem(from: sample)
            currentItemId = newItemBase.id
            return
        }

        let previouslyMoving = !workingItem.base.isVisit
        let currentlyMoving = sample.movingState != .stationary

        /** stationary -> moving || moving -> stationary **/
        if currentlyMoving != previouslyMoving {
            let newItemBase = await createTimelineItem(from: sample, previousItemId: workingItem.id)
            currentItemId = newItemBase.id
            return
        }

        /** stationary -> stationary || moving -> moving **/
        sample.timelineItemId = workingItem.id

        print("added sample to currentItem")

        // visit coordinate and radius need recalc
        workingItem.visit?.isStale = true

        do {
            try await Database.pool.write {
                _ = try sample.updateChanges($0)
                _ = try workingItem.visit?.updateChanges($0)
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
        if newItem.isVisit {
            newVisit = TimelineItemVisit(itemId: newItem.id, samples: [sample])
        } else {
            newVisit = nil
        }

        do {
            try await Database.pool.write {
                try newItem.save($0)
                try newVisit?.save($0)
                _ = try sample.updateChanges($0)
            }

            print("createTimelineItem() isVisit: \(newItem.isVisit)")

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        return newItem
    }

}
