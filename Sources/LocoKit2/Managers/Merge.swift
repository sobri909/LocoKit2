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
        if await !isValid(keeper: keeper, betweener: betweener, deadman: deadman, in: list) {
            return .impossible
        }
        return keeper.scoreForConsuming(deadman)
    }

    private static func isValid(keeper: TimelineItem, betweener: TimelineItem?, deadman: TimelineItem, in list: TimelineLinkedList) async -> Bool {
        if keeper.deleted || deadman.deleted || betweener?.deleted == true { return false }

        // check for dupes (which should be impossible, but weird stuff happens)
        var itemIds: Set<String> = [keeper.id, deadman.id]
        if let betweener {
            itemIds.insert(betweener.id)
            if itemIds.count != 3 { return false }
        } else {
            if itemIds.count != 2 { return false }
        }

        let keeperNext = await keeper.nextItem(in: list)
        let betweenerNext = await betweener?.nextItem(in: list)
        let deadmanNext = await deadman.nextItem(in: list)

        if let betweener {
            // keeper -> betweener -> deadman
            if keeperNext == betweener, betweenerNext == deadman { return true }
            // deadman -> betweener -> keeper
            if deadmanNext == betweener, betweenerNext == keeper { return true }
        } else {
            // keeper -> deadman
            if keeperNext == deadman { return true }
            // deadman -> keeper
            if deadmanNext == keeper { return true }
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

        let keeperPrevious = await keeper.previousItem(in: list)
        let keeperNext = await keeper.nextItem(in: list)
        guard let deadmanSamples = deadman.samples else { fatalError() }

        if let betweener {
            keeper.willConsume(betweener)
        }
        keeper.willConsume(deadman)

        do {
            return try await Database.pool.write {
                var mutableKeeper = self.keeper
                var mutableBetweener = self.betweener
                var mutableDeadman = self.deadman
                var samplesToMove: Set<LocomotionSample> = []

                // deadman is previous
                if keeperPrevious == self.deadman || (mutableBetweener != nil && keeperPrevious == mutableBetweener) {
                    mutableKeeper.base.previousItemId = mutableDeadman.base.previousItemId

                    // deadman is next
                } else if keeperNext == self.deadman || (mutableBetweener != nil && keeperNext == mutableBetweener) {
                    mutableKeeper.base.nextItemId = mutableDeadman.base.nextItemId

                } else {
                    fatalError()
                }

                /** deal with a betweener **/

                if let betweenerSamples = mutableBetweener?.samples {

                    // reassign betweener samples
                    for sample in betweenerSamples where !sample.disabled {
                        samplesToMove.insert(sample)
                    }

                    // TODO: move to the updateChanges below?
                    if betweenerSamples.contains(where: { $0.disabled }) {
                        mutableBetweener?.base.disabled = true
                    } else {
                        mutableBetweener?.base.deleted = true
                    }

                    mutableBetweener?.breakEdges()
                }

                /** deal with the deadman **/

                // reassign deadman samples
                for sample in deadmanSamples where !sample.disabled {
                    samplesToMove.insert(sample)
                }

                if deadmanSamples.contains(where: { $0.disabled }) {
                    mutableDeadman.base.disabled = true
                } else {
                    mutableDeadman.base.deleted = true
                }
                mutableDeadman.breakEdges()

                /** save the updated values **/

                try mutableKeeper.base.updateChanges($0, from: self.keeper.base)
                try mutableBetweener?.base.updateChanges($0, from: self.betweener!.base)
                try mutableDeadman.base.updateChanges($0, from: self.deadman.base)
                for var sample in samplesToMove {
                    try sample.updateChanges($0) {
                        $0.timelineItemId = self.keeper.id
                    }
                }

                if let mutableBetweener {
                    return (kept: mutableKeeper, killed: [mutableDeadman, mutableBetweener])
                } else {
                    return (kept: mutableKeeper, killed: [mutableDeadman])
                }
            }

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
        hasher.combine(keeper.dateRange.start)
    }

    nonisolated
    static func == (lhs: Merge, rhs: Merge) -> Bool {
        return (
            lhs.keeper == rhs.keeper &&
            lhs.deadman == rhs.deadman &&
            lhs.betweener == rhs.betweener &&
            lhs.keeper.dateRange.start == rhs.keeper.dateRange.start
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
