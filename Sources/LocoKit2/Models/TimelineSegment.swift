//
//  TimelineSegment.swift
//
//
//  Created by Matt Greenfield on 23/5/24.
//

import Foundation
import Combine
import UIKit
import GRDB

/// Provides an observable window into a timeline date range, designed for UI presentation
/// and foreground processing.
///
/// TimelineSegment automatically observes timeline changes via TimelineObserver and manages
/// data loading/processing for its date range. Applications should manage TimelineSegment
/// lifecycle in accordance with UI state and foreground/background transitions.
@MainActor
@Observable
public final class TimelineSegment: Sendable {

    public let dateRange: DateInterval
    public let shouldReprocessOnUpdate: Bool

    public private(set) var timelineItems: [TimelineItem] = []

    @ObservationIgnored
    public var potentiallyStaleData = false

    @ObservationIgnored
    nonisolated(unsafe)
    private var changesTask: Task<Void, Never>?

    private let updateDebouncer = Debouncer()

    public init(dateRange: DateInterval, shouldReprocessOnUpdate: Bool = false) {
        self.shouldReprocessOnUpdate = shouldReprocessOnUpdate
        self.dateRange = dateRange
        setupObserver()
        Task { await fetchItems() }
    }

    deinit {
        changesTask?.cancel()
    }

    // MARK: -

    public func pruneSamples() async {
        for item in timelineItems {
            do {
                try await item.pruneSamples()
            } catch {
                logger.error(error, subsystem: .timeline)
            }
        }
    }

    // MARK: - Private

    private func setupObserver() {
        changesTask = Task { [weak self] in
            for await changedRange in TimelineObserver.highlander.changesStream() {
                guard let self else { return }
                if self.dateRange.intersects(changedRange) {
                    self.updateDebouncer.debounce(duration: 1) { [weak self] in
                        await self?.fetchItems()
                    }
                }
            }
        }
    }

    private func fetchItems() async {
        do {
            let items = try await Database.pool.read { [dateRange] in
                return try TimelineItem
                    .itemRequest(includeSamples: false, includePlaces: true)
                    .filter(Column("deleted") == false && Column("disabled") == false)
                    .filter(Column("endDate") > dateRange.start && Column("startDate") < dateRange.end)
                    .order(Column("endDate").desc)
                    .fetchAll($0)
            }
            await update(from: items)

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    @ObservationIgnored
    nonisolated(unsafe)
    private var lastCurrentItemId: String?

    private func update(from updatedItems: [TimelineItem]) async {
        var mutableItems = updatedItems

        // load/copy samples
        for index in mutableItems.indices {
            let itemCopy = mutableItems[index]
            if itemCopy.samplesChanged || potentiallyStaleData {
                await mutableItems[index].fetchSamples()

            } else {
                // copy over existing samples if available
                let localItem = timelineItems.first { $0.id == itemCopy.id }
                if let localItem, let samples = localItem.samples {
                    mutableItems[index].samples = samples

                } else { // need to fetch samples
                    await mutableItems[index].fetchSamples()
                }
            }
        }

        let oldItems = timelineItems
        self.timelineItems = mutableItems

        // early return if we're not supposed to modify the items at all
        guard shouldReprocessOnUpdate else { return }
        guard UIApplication.shared.applicationState == .active else { return }

        // first classify
        await classifyItems(mutableItems)

        let recorder = await TimelineRecorder.highlander
        let currentItemId = await recorder.currentItemId

        // don't reprocess if currentItem is in segment and isn't a keeper
        if let currentItemId, let currentItem = mutableItems.first(where: { $0.id == currentItemId }) {
            do {
                if try !currentItem.isWorthKeeping { return }
            } catch {
                logger.error(error, subsystem: .timeline)
                return
            }
        }

        // if there's no currentItem, always process
        guard let currentItemId else {
            lastCurrentItemId = nil
            await TimelineProcessor.process(mutableItems)
            return
        }

        // check if anything besides currentItem changed
        let oldWithoutCurrent = oldItems.filter { $0.id != currentItemId }
        let newWithoutCurrent = mutableItems.filter { $0.id != currentItemId }

        // if only currentItem changed, skip processing
        if oldWithoutCurrent == newWithoutCurrent { return }

        // something else changed - do the processing
        lastCurrentItemId = currentItemId
        potentiallyStaleData = false
        await TimelineProcessor.process(mutableItems)
    }

    private func classifyItems(_ items: [TimelineItem]) async {
        var mutableItems = items
        for index in mutableItems.indices {
            await mutableItems[index].classifySamples()
        }
    }

}
