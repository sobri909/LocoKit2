//
// Created by Matt Greenfield on 25/05/16.
// Copyright (c) 2016 Big Paua. All rights reserved.
//

import Foundation
import GRDB

typealias MergeScore = ConsumptionScore
public typealias MergeResult = (kept: TimelineItem, killed: [TimelineItem])

@TimelineActor
internal final class Merge: Hashable, Sendable {

    let list: TimelineLinkedList
    let keeper: TimelineItem
    let betweener: TimelineItem?
    let deadman: TimelineItem
    let score: MergeScore

    /// `deadmanIsDisposable`: the deadman is a visit the user is deleting (BIG-865); its keeper
    /// status is ignored when scoring. Only `TimelineProcessor.safeDeleteVisit` passes true.
    init(keeper: TimelineItem, betweener: TimelineItem? = nil, deadman: TimelineItem, in list: TimelineLinkedList, deadmanIsDisposable: Bool = false) async {
        self.list = list
        self.keeper = keeper
        self.deadman = deadman
        self.betweener = betweener
        self.score = await Self.calculateScore(keeper: keeper, betweener: betweener, deadman: deadman, in: list, deadmanIsDisposable: deadmanIsDisposable)
    }

    // MARK: -

    private static func calculateScore(keeper: TimelineItem, betweener: TimelineItem?, deadman: TimelineItem, in list: TimelineLinkedList, deadmanIsDisposable: Bool) async -> MergeScore {
        guard await isValid(keeper: keeper, betweener: betweener, deadman: deadman, in: list) else {
            return .impossible
        }
        // NB: the betweener's content is deliberately not scored here. This is NOT a
        // gap (it's been repeatedly misdiagnosed as one): betweener-carrying merges
        // are only ever constructed when BOTH neighbours' keepnessScore strictly
        // exceeds the betweener's (collectBridgeMerges / collectAdjacentMerges in
        // TimelineProcessor+Merges.swift), so the betweener consult happens one
        // layer up, at collection time. Keeper-sized items never enter a bridge.
        return await keeper.scoreForConsuming(deadman, consumeeIsDisposable: deadmanIsDisposable)
    }

    private static func isValid(keeper: TimelineItem, betweener: TimelineItem?, deadman: TimelineItem, in list: TimelineLinkedList) async -> Bool {
        // check 1: basic state validity
        if keeper.deleted || deadman.deleted || betweener?.deleted == true { return false }
        if keeper.disabled || deadman.disabled || betweener?.disabled == true { return false }
        if keeper.locked || deadman.locked || betweener?.locked == true { return false }

        // check 2: items are in a valid merge pattern and result won't be circular or same-neighbor.
        // The same-neighbor checks compare the edge the keeper would inherit against the keeper's
        // other edge — only when the inherited edge is a real id. Two nils are not the same neighbor:
        // an island whose outer edges are both open (keeper at one end, deadman at the other) is
        // perfectly mergeable, and a plain `==` on the optionals rejected it for months, leaving
        // GPX-removal residue that no delete or heal could ever touch (BIG-714).
        if let betweener {
            // keeper -> betweener -> deadman
            if keeper.base.nextItemId == betweener.id, betweener.base.nextItemId == deadman.id {
                // keeper will inherit deadman's nextItemId
                if deadman.base.nextItemId == keeper.id { return false }
                if let inherited = deadman.base.nextItemId, inherited == keeper.base.previousItemId {
                    Log.error("Merge rejected: would create same-neighbor edges on keeper", subsystem: .timeline)
                    return false
                }
                return true
            }

            // deadman -> betweener -> keeper
            if deadman.base.nextItemId == betweener.id, betweener.base.nextItemId == keeper.id {
                // keeper will inherit deadman's previousItemId
                if deadman.base.previousItemId == keeper.id { return false }
                if let inherited = deadman.base.previousItemId, inherited == keeper.base.nextItemId {
                    Log.error("Merge rejected: would create same-neighbor edges on keeper", subsystem: .timeline)
                    return false
                }
                return true
            }

        } else {
            // keeper -> deadman
            if keeper.base.nextItemId == deadman.id {
                // keeper will inherit deadman's nextItemId
                if deadman.base.nextItemId == keeper.id { return false }
                if let inherited = deadman.base.nextItemId, inherited == keeper.base.previousItemId {
                    Log.error("Merge rejected: would create same-neighbor edges on keeper", subsystem: .timeline)
                    return false
                }
                return true
            }

            // deadman -> keeper
            if deadman.base.nextItemId == keeper.id {
                // keeper will inherit deadman's previousItemId
                if deadman.base.previousItemId == keeper.id { return false }
                if let inherited = deadman.base.previousItemId, inherited == keeper.base.nextItemId {
                    Log.error("Merge rejected: would create same-neighbor edges on keeper", subsystem: .timeline)
                    return false
                }
                return true
            }
        }

        return false
    }

    // MARK: -

    /// What `doIt()` did. A merge whose write was refused is told apart from one that was no longer
    /// valid by the time it ran (BIG-752): the processing loop acts on each, where a bare nil used to
    /// look the same for both and the loop retried a refused write against the same cached list forever.
    enum Outcome {
        case merged(MergeResult)
        /// the items no longer form this merge's pattern in the database (another merge or a heal
        /// moved an edge since the list was read); re-score from fresh rows
        case notValid
        /// the write threw; the transaction rolled back and nothing changed
        case failed(Error)
        /// merges are blocked (a partial import is in progress); the loop stops, nothing is retried
        case blocked
    }

    private struct NoLongerValid: Error {}

    /// The merge's identity across one processing call, for the loop's no-repeat belt (BIG-752).
    var key: String { "\(keeper.id)|\(betweener?.id ?? "-")|\(deadman.id)" }

    @discardableResult
    func doIt() async -> Outcome {
        // block merges during partial import to prevent corruption
        if await ImportState.hasPartialImport {
            Log.info("Merge blocked by partial import", subsystem: .timeline)
            return .blocked
        }

        // BIG-864: an executed merge is one line in the log file, always. Rejections were already
        // logged and merges were not, so a bundle could show the aftermath of a merge and nothing of
        // the decision; a merge is rare against samples and consequential against the timeline.
        // BIG-752: with the item ids and the keeper's day, so a storm names its items.
        if let description = try? description {
            let ids = [keeper.debugShortId, betweener?.debugShortId, deadman.debugShortId].compactMap { $0 }.joined(separator: " <- ")
            Log.info("Doing merge: \(description) [\(ids); \(keeper.dateRange?.start.description ?? "no date")]", subsystem: .timeline)
        }

        guard await Self.isValid(keeper: keeper, betweener: betweener, deadman: deadman, in: list) else {
            Log.error("Merge no longer valid", subsystem: .timeline)
            return .notValid
        }

        let mutableKeeper = keeper
        guard deadman.samples != nil else {
            // BIG-296: this should be impossible - samples should always be loaded for merge candidates
            Log.error("Merge.doIt() deadman has nil samples. deadman: \(deadman.id), deleted: \(deadman.deleted), disabled: \(deadman.disabled), score: \(score)", subsystem: .timeline)
            return .notValid
        }

        if let betweener {
            mutableKeeper.willConsume(betweener)
        }
        mutableKeeper.willConsume(deadman)

        // collect items to delete
        var itemsToDelete: Set<TimelineItem> = []
        if let betweener {
            itemsToDelete.insert(betweener)
        }
        itemsToDelete.insert(deadman)

        // do the db changes
        do {
            let result: MergeResult = try await Database.pool.write { [mutableKeeper, itemsToDelete] db in
                var mutableKeeper = mutableKeeper

                // BIG-752: the edge the keeper inherits is read from the rows as they are NOW, not from the
                // list's cache. After a merge the AFTER UPDATE edge triggers rewire the neighbours' edges in
                // the database while the loop's cache keeps their old copies; a keeper inheriting a cached
                // edge that points at an item deleted a moment earlier is refused by the BEFORE UPDATE
                // trigger, and a refused write with nothing invalidated re-ran against the same cache
                // forever (4,587 identical merges in 33 s on the 13 Pro, 2026-10-22).
                guard let freshKeeper = try TimelineItemBase.fetchOne(db, key: self.keeper.id),
                      let freshDeadman = try TimelineItemBase.fetchOne(db, key: self.deadman.id),
                      !freshKeeper.deleted, !freshKeeper.disabled, !freshKeeper.locked,
                      !freshDeadman.deleted, !freshDeadman.disabled, !freshDeadman.locked
                else { throw NoLongerValid() }
                var freshBetweener: TimelineItemBase?
                if let betweener = self.betweener {
                    guard let fresh = try TimelineItemBase.fetchOne(db, key: betweener.id),
                          !fresh.deleted, !fresh.disabled, !fresh.locked
                    else { throw NoLongerValid() }
                    freshBetweener = fresh
                }

                // the pattern from the fresh rows, and the far edge the keeper inherits
                let inheritsNext: Bool
                let inheritedId: String?
                if let freshBetweener {
                    if freshKeeper.nextItemId == freshBetweener.id, freshBetweener.nextItemId == freshDeadman.id {
                        inheritsNext = true; inheritedId = freshDeadman.nextItemId
                    } else if freshDeadman.nextItemId == freshBetweener.id, freshBetweener.nextItemId == freshKeeper.id {
                        inheritsNext = false; inheritedId = freshDeadman.previousItemId
                    } else { throw NoLongerValid() }
                } else {
                    if freshKeeper.nextItemId == freshDeadman.id {
                        inheritsNext = true; inheritedId = freshDeadman.nextItemId
                    } else if freshDeadman.nextItemId == freshKeeper.id {
                        inheritsNext = false; inheritedId = freshDeadman.previousItemId
                    } else { throw NoLongerValid() }
                }
                // a dangling inherited edge (its item deleted or missing) is inherited as nil and left to edge healing
                var edgeId = inheritedId
                if let candidate = inheritedId {
                    let live = try TimelineItemBase
                        .filter(TimelineItemBase.Columns.id == candidate)
                        .filter(TimelineItemBase.Columns.deleted == false)
                        .fetchCount(db) > 0
                    if !live {
                        Log.info("Merge: inherited \(inheritsNext ? "next" : "previous") edge \(candidate.split(separator: "-").first.map(String.init) ?? candidate) is deleted or missing; inheriting nil (BIG-752)", subsystem: .timeline)
                        edgeId = nil
                    }
                }

                // the circular and same-neighbour rules of isValid, on the fresh rows
                if edgeId == self.keeper.id { throw NoLongerValid() }
                if let edgeId, edgeId == (inheritsNext ? freshKeeper.previousItemId : freshKeeper.nextItemId) {
                    throw NoLongerValid()
                }

                // the write is the FRESH row plus the one inherited edge, so nothing the cache holds stale
                // (the recording item's end date, samplesChanged, lastSaved, the health fields) is written
                // back over what the database has now
                var keeperRow = freshKeeper
                if inheritsNext {
                    keeperRow.nextItemId = edgeId
                } else {
                    keeperRow.previousItemId = edgeId
                }

                // call merge hook before applying changes
                if let hook = TimelineItem.onItemMerge {
                    try hook(self.keeper, itemsToDelete, db)
                }

                try keeperRow.updateChanges(db, from: freshKeeper)
                mutableKeeper.base = keeperRow

                // move samples using SQL-level UPDATE to avoid stale in-memory snapshots (BIG-366)
                for item in itemsToDelete {
                    try LocomotionSample
                        .filter(LocomotionSample.Columns.timelineItemId == item.id)
                        .updateAll(db, LocomotionSample.Columns.timelineItemId.set(to: self.keeper.id))
                }

                for var item in itemsToDelete {
                    try item.base.updateChanges(db) {
                        $0.deleted = true
                    }
                }

                // mark affected places as stale so visit stats get recalculated
                let stalePlaceIds = Set(
                    [self.keeper.visit?.placeId, self.deadman.visit?.placeId, self.betweener?.visit?.placeId].compactMap { $0 }
                )
                for placeId in stalePlaceIds {
                    try Place
                        .filter(Place.Columns.id == placeId)
                        .updateAll(db, Place.Columns.isStale.set(to: true))
                }

                return (kept: mutableKeeper, killed: [self.deadman, self.betweener].compactMap { $0 })
            }

            return .merged(result)

        } catch is NoLongerValid {
            Log.info("Merge no longer valid against the database (an edge moved since the list was read); re-scoring", subsystem: .timeline)
            return .notValid
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
            // BIG-117 called these harmless: a concurrent run's race, converging on the next cycle. Across
            // calls it does; inside one call the next cycle read the same cache, so the loop now acts on
            // this (BIG-752), and a refused merge write goes to the log file rather than the console.
            Log.error("Merge write refused: \(error) [keeper \(keeper.debugShortId), deadman \(deadman.debugShortId)]", subsystem: .database)
            return .failed(error)
        } catch {
            Log.error(error, subsystem: .database)
            return .failed(error)
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
