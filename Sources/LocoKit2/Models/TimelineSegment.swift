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

@Observable
public final class TimelineSegment: Sendable {

    public let dateRange: DateInterval
    public let shouldReprocessOnUpdate: Bool

    @MainActor
    public private(set) var timelineItems: [TimelineItem] = []

    @ObservationIgnored
    nonisolated(unsafe)
    private var changesTask: Task<Void, Never>?

    @ObservationIgnored
    nonisolated(unsafe)
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
            if itemCopy.samplesChanged {
                await mutableItems[index].fetchSamples()

            } else {
                // copy over existing samples if available
                let localItem = await timelineItems.first { $0.id == itemCopy.id }
                if let localItem, let samples = localItem.samples {
                    mutableItems[index].samples = samples

                } else { // need to fetch samples
                    await mutableItems[index].fetchSamples()
                }
            }
        }

        let oldItems = await timelineItems
        await MainActor.run {
            self.timelineItems = mutableItems
        }

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
            await reprocess(items: mutableItems)
            return
        }

        // check if anything besides currentItem changed
        let oldWithoutCurrent = oldItems.filter { $0.id != currentItemId }
        let newWithoutCurrent = mutableItems.filter { $0.id != currentItemId }

        // if only currentItem changed, skip processing
        if oldWithoutCurrent == newWithoutCurrent { return }

        // something else changed - do the processing
        lastCurrentItemId = currentItemId
        await reprocess(items: mutableItems)
    }

    private func reprocess(items: [TimelineItem]) async {
        guard shouldReprocessOnUpdate else { return }
        guard await UIApplication.shared.applicationState == .active else { return }

        var mutableItems = items
        for index in mutableItems.indices {
            await mutableItems[index].classifySamples()
        }

        await TimelineProcessor.process(mutableItems)
    }

}
