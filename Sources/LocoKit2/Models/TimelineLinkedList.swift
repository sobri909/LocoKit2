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
            let seedItem = try await TimelineItem.fetchItem(itemId: seedItemId, includeSamples: true, includePlace: true)
            if let seedItem {
                self.seedItem = seedItem
                timelineItems[seedItemId] = seedItem
                observers[seedItemId] = await addObserverFor(itemId: seedItemId)
            } else {
                return nil
            }

        } catch {
            Log.error(error, subsystem: .database)
            return nil
        }
    }

    public convenience init(fromItems: [TimelineItem]) async {
        await self.init(fromItemIds: fromItems.map { $0.id })
    }

    public init(fromItemIds: [String]) async {
        for itemId in fromItemIds {
            observers[itemId] = await addObserverFor(itemId: itemId)
        }
    }

    public func itemFor(itemId: String) async -> TimelineItem? {
        if let cached = timelineItems[itemId] { return cached }

        await MainActor.run {
            if observers[itemId] == nil {
                observers[itemId] = addObserverFor(itemId: itemId)
            }
        }

        do {
            if let item = try await TimelineItem.fetchItem(itemId: itemId, includeSamples: true, includePlace: true) {
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
        get async {
            return await Array(observers.keys)
        }
    }

    // MARK: - Private

    private var timelineItems: [String: TimelineItem] = [:]

    private func receivedItem(_ item: TimelineItem) async {
        var mutableItem = item

        // is it stale?
        if mutableItem.samplesChanged, let samples = mutableItem.samples {
            await mutableItem.updateFrom(samples: samples)
        }
        
        timelineItems[item.id] = mutableItem
    }

    @MainActor
    private var observers: [String: AnyDatabaseCancellable] = [:]

    @MainActor
    private func addObserverFor(itemId: String) -> AnyDatabaseCancellable {
        return ValueObservation
            .trackingConstantRegion { db in
                let request = TimelineItem
                    .itemBaseRequest(includeSamples: true, includePlaces: true)
                    .filter { $0.id == itemId }
                return try request.asRequest(of: TimelineItem.self).fetchOne(db)
            }
            .removeDuplicates()
            .shared(in: Database.pool)
            .start { error in
                Log.error(error, subsystem: .database)

            } onChange: { [weak self] item in
                if let self, let item {
                    Task { await self.receivedItem(item) }
                }
            }
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
