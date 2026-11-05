//
//  TimelineLinkedList.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 6/6/24.
//

import Foundation
import GRDB

@TimelineActor
public final class TimelineLinkedList: AsyncSequence {

    public private(set) var seedItem: TimelineItem?

    public init?(fromItemId seedItemId: String) async {
        do {
            let fetched = try await TimelineItem.fetchItem(itemId: seedItemId, includeSamples: true, includePlace: true)
            if let fetched {
                let seedItem = await Self.refreshedOnLoad(fetched)
                self.seedItem = seedItem
                timelineItems[seedItemId] = seedItem
                trackedItemIds.insert(seedItemId)
            } else {
                return nil
            }

        } catch {
            Log.error(error, subsystem: .database)
            return nil
        }
        startObserving()
    }

    public convenience init(fromItems: [TimelineItem]) async {
        await self.init(fromItemIds: fromItems.map { $0.id })
    }

    public init(fromItemIds: [String]) async {
        trackedItemIds = Set(fromItemIds)
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    public func itemFor(itemId: String) async -> TimelineItem? {
        if let cached = timelineItems[itemId] { return cached }

        trackedItemIds.insert(itemId)

        do {
            if let fetched = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true, includePlace: true) {
                let item = await Self.refreshedOnLoad(fetched)
                // the observer may have stored a newer copy while this one loaded (reviewer, 2026-11-05)
                if let newer = timelineItems[itemId] { return newer }
                timelineItems[item.id] = item
                return item
            } else {
                return nil
            }

        } catch {
            Log.error(error, subsystem: .database)
            return nil
        }
    }

    public func previousItem(for item: TimelineItem) async -> TimelineItem? {
        guard let previousItemId = item.base.previousItemId else { return nil }
        return await itemFor(itemId: previousItemId)
    }

    public func nextItem(for item: TimelineItem) async -> TimelineItem? {
        guard let nextItemId = item.base.nextItemId else { return nil }
        return await itemFor(itemId: nextItemId)
    }

    public func invalidate(itemId: String) {
        timelineItems.removeValue(forKey: itemId)
    }

    public var count: Int {
        return timelineItems.count
    }

    public var itemIds: [String] {
        return Array(trackedItemIds)
    }

    // MARK: - Private

    private var timelineItems: [String: TimelineItem] = [:]
    private var trackedItemIds: Set<String> = []
    private var observationTask: Task<Void, Never>?

    private func startObserving() {
        observationTask = Task { [weak self] in
            for await changedIds in TimelineItemObserver.highlander.changesStream() {
                guard let self else { return }
                let relevantIds = changedIds.intersection(self.trackedItemIds)
                for itemId in relevantIds {
                    do {
                        if let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true, includePlace: true) {
                            await self.receivedItem(item)
                        }
                    } catch {
                        Log.error(error, subsystem: .database)
                    }
                }
            }
        }
    }

    private func receivedItem(_ item: TimelineItem) async {
        var mutableItem = item

        // is it stale?
        if mutableItem.samplesChanged, let samples = mutableItem.samples {
            await mutableItem.updateFrom(samples: samples)
        }

        timelineItems[item.id] = mutableItem
    }

    /// BIG-308: the recorder creates a trip from its first sample (stored distance 0) and attaches the rest
    /// without refreshing the item's derived fields, and processing scores from those fields: `isValid` and
    /// `isWorthKeeping` read the stored trip distance. This list refreshed a stale item only when a change
    /// arrived for it (usually an edge steal), so a trip that reached scoring with nothing stolen read as
    /// invalid and a neighbouring visit swallowed it (`StaleTripProcessingTests`).
    ///
    /// So an item loaded stale gets the full `updateFrom` before it is scored: its trip and visit fields
    /// recomputed and written once, and `samplesChanged` cleared, so the next load doesn't repeat it. That
    /// is safe in the background since BIG-963 took HealthKit out of `updateFrom`; before it, clearing the
    /// flag here after a skipped health fetch left the item's health never fetched (reviewer, 2026-11-05).
    /// Health now follows its own date, which the item's moved dates have already cleared. Deleted items
    /// are left alone.
    ///
    /// The log line counts how often the gap was live: a refresh that turned an item valid or a keeper.
    private static func refreshedOnLoad(_ item: TimelineItem) async -> TimelineItem {
        guard !item.deleted, item.samplesChanged, let samples = item.samples, !samples.isEmpty else { return item }

        let wasValid = try? item.isValid
        let wasKeeper = try? item.isWorthKeeping

        var refreshed = item
        await refreshed.updateFrom(samples: samples)

        let isValid = try? refreshed.isValid
        let isKeeper = try? refreshed.isWorthKeeping
        if (wasValid == false && isValid == true) || (wasKeeper == false && isKeeper == true) {
            let old = item.trip?.distance ?? 0
            let new = refreshed.trip?.distance ?? 0
            let distances = old.isFinite && new.isFinite ? "\(Int(old)) → \(Int(new)) m" : "?"
            Log.info("TimelineLinkedList: stale \(item.isVisit ? "visit" : "trip") \(item.debugShortId) refreshed on load before scoring: \(samples.count) samples, distance \(distances), valid \(wasValid == true) → \(isValid == true), keeper \(wasKeeper == true) → \(isKeeper == true) (BIG-308)", subsystem: .timeline)
        }

        return refreshed
    }

    // MARK: - AsyncSequence

    public typealias Element = TimelineItem
    public typealias AsyncIterator = ItemsAsyncIterator

    nonisolated
    public func makeAsyncIterator() -> ItemsAsyncIterator {
        return ItemsAsyncIterator(list: self)
    }

    public struct ItemsAsyncIterator: AsyncIteratorProtocol {
        private let list: TimelineLinkedList
        private var itemIds: [String] = []
        private var currentIndex: Int = 0
        private var isInitialized = false

        init(list: TimelineLinkedList) {
            self.list = list
        }

        public mutating func next() async -> TimelineItem? {
            if !isInitialized {
                itemIds = await list.itemIds
                isInitialized = true
            }

            while currentIndex < itemIds.count {
                let itemId = itemIds[currentIndex]
                currentIndex += 1

                if let item = await list.itemFor(itemId: itemId),
                   !item.deleted {
                    return item
                }
            }

            return nil
        }
    }

}
