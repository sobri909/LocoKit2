//
//  TimelineSegment.swift
//
//
//  Created by Matt Greenfield on 23/5/24.
//

import Foundation
import Combine
import GRDB

@Observable
public final class TimelineSegment: Sendable {

    public let dateRange: DateInterval

    @MainActor
    public private(set) var timelineItems: [TimelineItem] = []

    @ObservationIgnored
    nonisolated(unsafe)
    public var shouldReprocessOnUpdate = false

    @ObservationIgnored
    nonisolated(unsafe)
    private var changesTask: Task<Void, Never>?

    public init(dateRange: DateInterval) {
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
            guard let self else { return }
            for await changedRange in TimelineObserver.highlander.changesStream() {
                if self.dateRange.intersects(changedRange) {
                    await self.fetchItems()
                }
            }
        }
    }

    private func fetchItems() async {
        do {
            let items = try await Database.pool.read { [dateRange] in
                let request = TimelineItemBase
                    .including(optional: TimelineItemBase.visit)
                    .including(optional: TimelineItemBase.trip)
                    .filter(Column("endDate") > dateRange.start && Column("startDate") < dateRange.end)
                    .order(Column("endDate").desc)
                return try TimelineItem.fetchAll($0, request)
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
                await mutableItems[index].fetchSamples(andClassify: shouldReprocessOnUpdate)

            } else {
                // copy over existing samples if available
                let localItem = await timelineItems.first { $0.id == itemCopy.id }
                if let localItem, let samples = localItem.samples {
                    mutableItems[index].samples = samples

                } else { // need to fetch samples
                    await mutableItems[index].fetchSamples(andClassify: shouldReprocessOnUpdate)
                }
            }
        }

        await MainActor.run {
            self.timelineItems = mutableItems
        }

        if shouldReprocessOnUpdate {
            await reprocess()
        }
    }

    private func reprocess() async {
        let workingItems = await timelineItems
        let currentItemId = TimelineRecorder.highlander.currentItemId
        let currentItem = await timelineItems.first { $0.id == currentItemId }

        // shouldn't do processing if currentItem is in the segment and isn't a keeper
        // (TimelineRecorder should be the sole authority on processing those cases)
        do {
            if let currentItem, try !currentItem.isWorthKeeping {
                return
            }
        } catch {
            logger.error("Throw on currentItem.isWorthKeeping", subsystem: .timeline)
        }

        let list = await TimelineLinkedList(fromItems: workingItems)
        await TimelineProcessor.highlander.process(list)
    }

}
