//
//  TimelineLinkedList.swift
//
//
//  Created by Matt Greenfield on 6/6/24.
//

import Foundation
import Combine
import GRDB

@TimelineActor
public final class TimelineLinkedList: AsyncSequence {

    public private(set) var seedItem: TimelineItem?

    public init?(fromItemId seedItemId: String) async {
        do {
            let seedItem = try await Database.pool.read {
                try TimelineItemBase
                    .including(optional: TimelineItemBase.visit)
                    .including(optional: TimelineItemBase.trip)
                    .including(all: TimelineItemBase.samples)
                    .filter(Column("id") == seedItemId)
                    .asRequest(of: TimelineItem.self)
                    .fetchOne($0)
            }
            if let seedItem {
                self.seedItem = seedItem
                timelineItems[seedItemId] = seedItem
                observers[seedItemId] = addObserverFor(itemId: seedItemId)

            } else {
                return nil
            }

        } catch {
            logger.error(error, subsystem: .database)
            return nil
        }
    }

    public init(fromItems: [TimelineItem]) {
        for item in fromItems {
            timelineItems[item.id] = item
            observers[item.id] = addObserverFor(itemId: item.id)
        }
    }

    public func itemFor(itemId: String) async -> TimelineItem? {
        if let cached = timelineItems[itemId] { return cached }

        if observers[itemId] == nil {
            observers[itemId] = addObserverFor(itemId: itemId)
        }

        do {
            let item = try await Database.pool.read {
                try TimelineItemBase
                    .including(optional: TimelineItemBase.visit)
                    .including(optional: TimelineItemBase.trip)
                    .including(all: TimelineItemBase.samples)
                    .filter(Column("id") == itemId)
                    .asRequest(of: TimelineItem.self)
                    .fetchOne($0)
            }
            if let item {
                timelineItems[item.id] = item
            }
            return item

        } catch {
            logger.error(error, subsystem: .database)
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
        return Array(timelineItems.keys)
    }

    // MARK: - Private

    private var timelineItems: [String: TimelineItem] = [:]

    private func receivedItem(_ item: TimelineItem) {
        timelineItems[item.id] = item
    }

    private var observers: [String: AnyCancellable] = [:]

    nonisolated
    private func addObserverFor(itemId: String) -> AnyCancellable {
        return ValueObservation
            .trackingConstantRegion { db in
                try TimelineItemBase
                    .including(optional: TimelineItemBase.visit)
                    .including(optional: TimelineItemBase.trip)
                    .including(all: TimelineItemBase.samples)
                    .filter(Column("id") == itemId)
                    .asRequest(of: TimelineItem.self)
                    .fetchOne(db)
            }
            .shared(in: Database.pool, scheduling: .async(onQueue: TimelineActor.queue))
            .publisher()
            .sink { completion in
                if case .failure(let error) = completion {
                    logger.error(error, subsystem: .database)
                }
            } receiveValue: { [weak self] item in
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
