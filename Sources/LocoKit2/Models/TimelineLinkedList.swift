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
public final class TimelineLinkedList {

    public private(set) var seedItem: TimelineItem
    public private(set) var timelineItems: [String: TimelineItem] = [:]

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
                timelineItems[seedItem.id] = seedItem
            } else {
                return nil
            }

        } catch {
            logger.error(error, subsystem: .database)
            return nil
        }
    }

    public func previousItem(for item: TimelineItem) async -> TimelineItem? {
        guard let previousItemId = item.base.previousItemId else { return nil }
        return await getItem(itemId: previousItemId)
    }

    public func nextItem(for item: TimelineItem) async -> TimelineItem? {
        guard let nextItemId = item.base.nextItemId else { return nil }
        return await getItem(itemId: nextItemId)
    }

    // MARK: - Private

    private var cancellables: [String: AnyCancellable] = [:]

    private func getItem(itemId: String) async -> TimelineItem? {
        if let cached = timelineItems[itemId] { return cached }

        addObserverFor(itemId: itemId)

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

    private func addObserverFor(itemId: String) {
        guard cancellables[itemId] == nil else { return }

        let cancellable = ValueObservation
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
            } receiveValue: { item in
                if let item {
                    self.timelineItems[item.id] = item
                }
            }

        cancellables[itemId] = cancellable
    }

}
