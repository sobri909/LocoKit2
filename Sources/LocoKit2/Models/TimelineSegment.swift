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

    @ObservationIgnored
    nonisolated(unsafe)
    private var processingTask: Task<Void, Never>?

    @ObservationIgnored
    nonisolated(unsafe)
    private var processingInterrupted = false

    private let updateDebouncer = Debouncer()

    public init(dateRange: DateInterval, shouldReprocessOnUpdate: Bool = false) {
        self.shouldReprocessOnUpdate = shouldReprocessOnUpdate
        self.dateRange = dateRange
        setupObserver()
        Task { await fetchItems() }
    }

    deinit {
        changesTask?.cancel()
        processingTask?.cancel()
    }

    // MARK: - Processing lifecycle

    public func cancelProcessing() {
        guard processingTask != nil else { return }
        processingTask?.cancel()
        processingTask = nil
        processingInterrupted = true
    }

    public func resumeProcessingIfNeeded() {
        guard processingInterrupted, shouldReprocessOnUpdate else { return }
        processingInterrupted = false
        Task { await fetchItems() }
    }

    // MARK: -

    public func pruneSamples(excluding prunedItemIds: inout Set<String>) async {
        guard let timelineItems else { return }
        for item in timelineItems {
            guard !prunedItemIds.contains(item.id) else { continue }
            prunedItemIds.insert(item.id)
            do {
                try await item.pruneSamples()
            } catch {
                Log.error(error, subsystem: .timeline)
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
        guard let handle = OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineSegment.fetchItems()",
            objectKey: dateRange.description,
            rejectDuplicates: true
        ) else {
            // info, not debug: a bundle has to show a segment starved by its own in-flight fetch
            // (BIG-789) — but on exactly such a device this fires every second, so once a minute
            if logDuplicateSkip(.fetch) {
                Log.info("Skipping duplicate TimelineSegment.fetchItems() (\(dateRange.start.formatted(date: .abbreviated, time: .omitted)))", subsystem: .timeline)
            }
            return
        }
        defer { OperationRegistry.endOperation(handle) }

        let start = Date()
        do {
            let items = try await Database.pool.read { [dateRange] db in
                let request = TimelineItem
                    .itemBaseRequest(includeSamples: false, includePlaces: true)
                    .filter(TimelineItemBase.Columns.deleted == false && TimelineItemBase.Columns.disabled == false)
                    .filter(TimelineItemBase.Columns.endDate > dateRange.start && TimelineItemBase.Columns.startDate < dateRange.end)
                    .order(TimelineItemBase.Columns.endDate.desc)
                return try request.asRequest(of: TimelineItem.self).fetchAll(db)
            }
            await update(from: items)

            // BIG-789: a day view that takes minutes to load was invisible in every bundle
            let elapsed = -start.timeIntervalSinceNow
            if elapsed > 2 {
                let sampleCount = timelineItems?.reduce(0) { $0 + ($1.samples?.count ?? 0) } ?? 0
                Log.info("TimelineSegment.fetchItems() took \(String(format: "%.1f", elapsed))s: \(items.count) items, \(sampleCount) samples, \(dateRange.start.formatted(date: .abbreviated, time: .omitted))", subsystem: .timeline)
            }

        } catch is CancellationError {
            // CancellationError is fine here; can ignore

        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    @ObservationIgnored
    nonisolated(unsafe)
    private var lastCurrentItemId: String?

    private enum DuplicateSkip { case fetch, classify }

    @ObservationIgnored
    nonisolated(unsafe)
    private var lastDuplicateSkipLog: [DuplicateSkip: Date] = [:]

    /// One duplicate-skip line per minute per segment and kind: enough to show a starved
    /// segment in a bundle, not enough to fill the log file on the device it is meant to diagnose.
    private func logDuplicateSkip(_ kind: DuplicateSkip) -> Bool {
        if let last = lastDuplicateSkipLog[kind], last.age < 60 { return false }
        lastDuplicateSkipLog[kind] = .now
        return true
    }

    private func update(from updatedItems: [TimelineItem]) async {
        guard let handle = OperationRegistry.startOperation(.timeline, operation: "TimelineSegment.update(from:)", objectKey: dateRange.description) else { return }
        defer { OperationRegistry.endOperation(handle) }
        
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
        guard UIApplication.shared.applicationState == .active else {
            // BIG-789: on a slow day view the load outlives the foreground session that started
            // it, and nothing was classified or processed for days with no line saying why
            Log.info("TimelineSegment.update(from:) skipped classify/process: app not active (\(newItems.count) items)", subsystem: .timeline)
            return
        }

        processingTask?.cancel()
        processingTask = Task {
            await classify(items: newItems)
            await processItems(newItems, oldItems: oldItems)
        }
    }

    private func classify(items: [TimelineItem]) async {
        guard let handle = OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineSegment.classify(items:)",
            objectKey: dateRange.description,
            rejectDuplicates: true
        ) else {
            if logDuplicateSkip(.classify) {
                Log.info("Skipping duplicate TimelineSegment.classify(items:) (\(dateRange.start.formatted(date: .abbreviated, time: .omitted)))", subsystem: .timeline)
            }
            return
        }

        defer { OperationRegistry.endOperation(handle) }

        let start = Date()
        var mutableItems = items
        for index in mutableItems.indices {
            if Task.isCancelled {
                // routine on a recording day (every refetch cancels the running pass); only a
                // pass that had already run long is worth a line
                let elapsed = -start.timeIntervalSinceNow
                if elapsed > 2 {
                    Log.info("TimelineSegment.classify(items:) cancelled after \(index)/\(items.count) items, \(String(format: "%.1f", elapsed))s", subsystem: .timeline)
                }
                return
            }
            await mutableItems[index].classifySamples()
        }
        let elapsed = -start.timeIntervalSinceNow
        if elapsed > 2 {
            Log.info("TimelineSegment.classify(items:) done: \(items.count) items, \(String(format: "%.1f", elapsed))s", subsystem: .timeline)
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
                Log.error(error, subsystem: .timeline)
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
