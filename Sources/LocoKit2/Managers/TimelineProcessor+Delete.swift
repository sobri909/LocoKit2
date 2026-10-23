//
//  TimelineProcessor+Delete.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation

@TimelineActor
extension TimelineProcessor {

    public static func safeDeleteVisit(_ deadman: TimelineItem) async {
        guard deadman.isVisit else {
            Log.error("safeDeleteVisit() called on non-Visit item", subsystem: .timeline)
            return
        }

        guard let handle = OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineProcessor.safeDeleteVisit(_:)",
            objectKey: deadman.id,
            rejectDuplicates: true
        ) else {
            Log.debug("Skipping duplicate TimelineProcessor.safeDeleteVisit(_:)", subsystem: .timeline)
            return
        }

        defer { OperationRegistry.endOperation(handle) }

        if TimelineProcessor.debugLogging {
            print("TimelineProcessor.safeDeleteVisit()")
        }

        // get the linked list context for edge finding
        guard let list = await TimelineLinkedList(fromItemId: deadman.id) else { return }

        // strip keeper properties from target Visit to allow proper merge scoring
        // this ensures the most sensible merge wins rather than all merges scoring .impossible
        var mutableDeadman = deadman
        if let visit = mutableDeadman.visit {
            var mutableVisit = visit
            mutableVisit.placeId = nil
            mutableVisit.confirmedPlace = false
            mutableVisit.customTitle = nil
            mutableDeadman.visit = mutableVisit
        }

        // BIG-865: bridges (a neighbour consuming the deadman AND the other neighbour) and
        // adjacent merges (a neighbour consuming only the deadman) are kept apart, because
        // only the adjacent ones may run as a fallback. The deadman is scored as disposable
        // in the adjacent merges: the user has said it isn't worth keeping, so its keeper
        // duration can't make every candidate .impossible (which is what used to hand the
        // choice to Set hash order, and let a bridge delete a keeper trip the user never
        // touched).
        var bridgeMerges: Set<Merge> = []
        var adjacentMerges: Set<Merge> = []

        // try merge next and previous
        if let next = await mutableDeadman.nextItem(in: list),
            let previous = await mutableDeadman.previousItem(in: list) {
            bridgeMerges.insert(await Merge(keeper: next, betweener: mutableDeadman, deadman: previous, in: list))
            bridgeMerges.insert(await Merge(keeper: previous, betweener: mutableDeadman, deadman: next, in: list))
        }

        // try merge into previous
        if let previous = await mutableDeadman.previousItem(in: list) {
            adjacentMerges.insert(await Merge(keeper: previous, deadman: mutableDeadman, in: list, deadmanIsDisposable: true))
        }

        // try merge into next
        if let next = await mutableDeadman.nextItem(in: list) {
            adjacentMerges.insert(await Merge(keeper: next, deadman: mutableDeadman, in: list, deadmanIsDisposable: true))
        }

        // highest score first; on equal scores an adjacent merge sorts ahead of a bridge, so a
        // tie never hands "which neighbour also dies" to Set order
        let sortedMerges = bridgeMerges.union(adjacentMerges).sorted {
            ($0.score.rawValue, $0.betweener == nil ? 1 : 0) > ($1.score.rawValue, $1.betweener == nil ? 1 : 0)
        }

        if TimelineProcessor.debugLogging {
            print("Considering \(sortedMerges.count) merges")
            if let bestScore = sortedMerges.first?.score {
                print("Best merge score: \(bestScore)")
            }
        }

        // the best scoring merge, when one actually scores
        if let winningMerge = sortedMerges.first, winningMerge.score != .impossible {
            if case .merged(let results) = await winningMerge.doIt() {
                await processFrom(itemId: results.kept.id)
            } else {
                // a failed doIt() writes nothing (the transaction rolls back), so the visit is
                // simply still there; no fallback, since the scored merge was the right one
                Log.info("safeDeleteVisit: the winning merge didn't apply; visit left as is", subsystem: .timeline)
            }
            return
        }

        // nothing scores: the user still wants the visit gone, so fall back to an adjacent
        // merge (the deadman's own samples into its nearer neighbour). Never a bridge: a
        // bridge also deletes the other neighbour, which the user didn't ask for. Data gap
        // and nolo neighbours are left out: located samples merged into them would stop
        // them being what they are. Ties on distance go to the neighbour worth more.
        func fallbackRank(_ merge: Merge) -> (Double, Int) {
            let gap = ((try? merge.keeper.distance(from: mutableDeadman)) ?? nil) ?? .greatestFiniteMagnitude
            let keepness = (try? merge.keeper.keepnessScore) ?? 0
            return (gap, -keepness)
        }
        let fallback = adjacentMerges
            .filter { ((try? $0.keeper.isDataGap) ?? true) == false && ((try? $0.keeper.isNolo) ?? true) == false }
            .min { fallbackRank($0) < fallbackRank($1) }
        if let fallback {
            Log.info("safeDeleteVisit: no merge scored above impossible; falling back to adjacent merge into \(fallback.keeper.isVisit ? "visit" : "trip") \(fallback.keeper.id)", subsystem: .timeline)
            if case .merged(let results) = await fallback.doIt() {
                await processFrom(itemId: results.kept.id)
                return
            }
        }

        if TimelineProcessor.debugLogging {
            print("TimelineProcessor.safeDeleteVisit() failed - no valid merges found")
        }
    }

}
