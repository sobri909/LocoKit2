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
    public var shouldReprocessOnUpdate: Bool

    public private(set) var timelineItems: [TimelineItem]?

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
        guard let timelineItems else { return }
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
        guard let handle = await OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineSegment.fetchItems()",
            objectKey: dateRange.description,
            rejectDuplicates: true
        ) else {
            logger.info("Skipping duplicate TimelineSegment.fetchItems()", subsystem: .timeline)
            return
        }
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        do {
            let items = try await Database.pool.read { [dateRange] db in
                let request = TimelineItem
                    .itemBaseRequest(includeSamples: false, includePlaces: true)
                    .filter { $0.deleted == false && $0.disabled == false }
                    .filter { $0.endDate > dateRange.start && $0.startDate < dateRange.end }
                    .order(\.endDate.desc)
                return try request
                    .asRequest(of: TimelineItem.self)
                    .fetchAll(db)
            }
            await update(from: items)

        } catch is CancellationError {
            // CancellationError is fine here; can ignore

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    @ObservationIgnored
    nonisolated(unsafe)
    private var lastCurrentItemId: String?

    private func update(from updatedItems: [TimelineItem]) async {
        guard let handle = await OperationRegistry.startOperation(.timeline, operation: "TimelineSegment.update(from:)", objectKey: dateRange.description) else { return }
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        let oldItems = timelineItems ?? []
        var newItems = updatedItems

        // load/copy samples
        for index in newItems.indices {
            let newItem = newItems[index]
            if newItem.samplesChanged {
                await newItems[index].fetchSamples()

            } else {
                let oldItem = oldItems.first { $0.id == newItem.id }

                // copy over existing samples if item hasn't changed
                if let oldItem, let samples = oldItem.samples, !newItem.hasChanged(from: oldItem) {
                    newItems[index].samples = samples

                } else { // need to fetch samples
                    await newItems[index].fetchSamples()
                }
            }
        }

        self.timelineItems = newItems

        if Task.isCancelled { return }
        
        // early return if we're not supposed to modify the items at all
        guard shouldReprocessOnUpdate else { return }
        guard UIApplication.shared.applicationState == .active else { return }

        Task {
            await classify(items: newItems)
            await processItems(newItems, oldItems: oldItems)
        }
    }

    private func classify(items: [TimelineItem]) async {
        guard let handle = await OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineSegment.classify(items:)",
            objectKey: dateRange.description,
            rejectDuplicates: true
        ) else {
            logger.info("Skipping duplicate TimelineSegment.classify(items:)", subsystem: .timeline)
            return
        }

        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        var mutableItems = items
        for index in mutableItems.indices {
            if Task.isCancelled { return }
            await mutableItems[index].classifySamples()
        }
    }

    private func processItems(_ newItems: [TimelineItem], oldItems: [TimelineItem]) async {
        if Task.isCancelled { return }
        
        let currentItemId = await TimelineRecorder.currentItemId

        // don't reprocess if currentItem is in segment and isn't a keeper
        if let currentItemId, let currentItem = newItems.first(where: { $0.id == currentItemId }) {
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
            await TimelineProcessor.process(items: newItems)
            return
        }

        // check if anything besides currentItem changed
        let oldWithoutCurrent = oldItems.filter { $0.id != currentItemId }
        let newWithoutCurrent = newItems.filter { $0.id != currentItemId }

        // if only currentItem changed, skip processing
        if oldWithoutCurrent == newWithoutCurrent { return }

        // something else changed - do the processing
        lastCurrentItemId = currentItemId
        await TimelineProcessor.process(items: newItems)
    }

}
