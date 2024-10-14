//
// Created by Matt Greenfield on 25/05/16.
// Copyright (c) 2016 Big Paua. All rights reserved.
//

import Foundation

typealias MergeScore = ConsumptionScore
public typealias MergeResult = (kept: TimelineItem, killed: [TimelineItem])

@TimelineActor
internal final class Merge: Hashable, Sendable {

    let list: TimelineLinkedList
    let keeper: TimelineItem
    let betweener: TimelineItem?
    let deadman: TimelineItem
    let score: MergeScore

    init(keeper: TimelineItem, betweener: TimelineItem? = nil, deadman: TimelineItem, in list: TimelineLinkedList) async {
        self.list = list
        self.keeper = keeper
        self.deadman = deadman
        self.betweener = betweener
        self.score = await Self.calculateScore(keeper: keeper, betweener: betweener, deadman: deadman, in: list)
    }

    // MARK: -

    private static func calculateScore(keeper: TimelineItem, betweener: TimelineItem?, deadman: TimelineItem, in list: TimelineLinkedList) async -> MergeScore {
        guard await isValid(keeper: keeper, betweener: betweener, deadman: deadman, in: list) else {
            return .impossible
        }
        return keeper.scoreForConsuming(deadman)
    }

    private static func isValid(keeper: TimelineItem, betweener: TimelineItem?, deadman: TimelineItem, in list: TimelineLinkedList) async -> Bool {
        if keeper.deleted || deadman.deleted || betweener?.deleted == true { return false }
        if keeper.disabled || deadman.disabled || betweener?.disabled == true { return false }

        if let betweener {
            // keeper -> betweener -> deadman
            if keeper.base.nextItemId == betweener.id, betweener.base.nextItemId == deadman.id { return true }
            // deadman -> betweener -> keeper
            if deadman.base.nextItemId == betweener.id, betweener.base.nextItemId == keeper.id { return true }
        } else {
            // keeper -> deadman
            if keeper.base.nextItemId == deadman.id { return true }
            // deadman -> keeper
            if deadman.base.nextItemId == keeper.id { return true }
        }

        return false
    }

    // MARK: -

    @discardableResult
    func doIt() async -> MergeResult? {
        if TimelineProcessor.debugLogging {
            if let description = try? description {
                logger.info("Doing:\n\(description)")
            }
        }

        var mutableKeeper = keeper
        let keeperPrevious = await keeper.previousItem(in: list)
        let keeperNext = await keeper.nextItem(in: list)
        guard let deadmanSamples = deadman.samples else { fatalError() }

        if let betweener {
            mutableKeeper.willConsume(betweener)
        }
        mutableKeeper.willConsume(deadman)

        var samplesToMove: Set<LocomotionSample> = []
        var itemsToDelete: Set<TimelineItem> = []

        // deadman is previous
        if keeperPrevious == self.deadman || (betweener != nil && keeperPrevious == betweener) {
            mutableKeeper.base.previousItemId = deadman.base.previousItemId

            // deadman is next
        } else if keeperNext == self.deadman || (betweener != nil && keeperNext == betweener) {
            mutableKeeper.base.nextItemId = deadman.base.nextItemId

        } else {
            logger.error("Merge no longer valid", subsystem: .timeline)
            return nil
        }

        /** deal with a betweener **/

        if let betweener, let betweenerSamples = betweener.samples {
            samplesToMove.formUnion(betweenerSamples)
            itemsToDelete.insert(betweener)
        }

        /** deal with the deadman **/

        samplesToMove.formUnion(deadmanSamples)
        itemsToDelete.insert(deadman)

        do {
            try await Database.pool.write { [mutableKeeper, samplesToMove, itemsToDelete] db in
                try mutableKeeper.base.updateChanges(db, from: self.keeper.base)
                for var sample in samplesToMove {
                    try sample.updateChanges(db) {
                        $0.timelineItemId = self.keeper.id
                    }
                }
                for var item in itemsToDelete {
                    try item.base.updateChanges(db) {
                        $0.deleted = true
                    }
                }
            }

            return (kept: mutableKeeper, killed: [deadman, betweener].compactMap { $0 })

        } catch {
            logger.error(error, subsystem: .database)
            return nil
        }
    }

    // MARK: - Hashable

    nonisolated
    func hash(into hasher: inout Hasher) {
        hasher.combine(keeper)
        hasher.combine(deadman)
        if let betweener {
            hasher.combine(betweener)
        }
        if let start = keeper.dateRange?.start {
            hasher.combine(start)
        }
    }

    nonisolated
    static func == (lhs: Merge, rhs: Merge) -> Bool {
        return (
            lhs.keeper == rhs.keeper &&
            lhs.deadman == rhs.deadman &&
            lhs.betweener == rhs.betweener &&
            lhs.keeper.dateRange?.start == rhs.keeper.dateRange?.start
        )
    }

    var description: String {
        get throws {
            if let betweener {
                return String(
                    format: "score: %d (%@) <- (%@) <- (%@)", score.rawValue,
                    try keeper.description, try betweener.description, try deadman.description
                )
            }
            return String(
                format: "score: %d (%@) <- (%@)", score.rawValue,
                try keeper.description, try deadman.description
            )
        }
    }
    
}
