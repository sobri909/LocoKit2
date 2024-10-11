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
                    .itemRequest(includeSamples: false)
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

    private func update(from updatedItems: [TimelineItem]) async {
        var mutableItems = updatedItems

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

        await MainActor.run {
            self.timelineItems = mutableItems
        }

        await reprocess(items: mutableItems)
    }

    private func reprocess(items: [TimelineItem]) async {
        guard shouldReprocessOnUpdate else { return }

        // no reprocessing in the background
        guard await UIApplication.shared.applicationState == .active else { return }

        do {
            var mutableItems = items
            let currentItemId = TimelineRecorder.highlander.currentItemId
            let currentItem = mutableItems.first { $0.id == currentItemId }

            // shouldn't do processing if currentItem is in the segment and isn't a keeper
            if let currentItem, try !currentItem.isWorthKeeping {
                return
            }

            for index in mutableItems.indices {
                await mutableItems[index].classifySamples()
            }

            await TimelineProcessor.process(mutableItems)

        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

}
