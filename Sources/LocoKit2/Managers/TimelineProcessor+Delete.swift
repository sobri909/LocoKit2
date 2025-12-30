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

        guard let handle = await OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineProcessor.safeDeleteVisit(_:)",
            objectKey: deadman.id,
            rejectDuplicates: true
        ) else {
            Log.info("Skipping duplicate TimelineProcessor.safeDeleteVisit(_:)", subsystem: .timeline)
            return
        }

        defer { Task { await OperationRegistry.endOperation(handle) } }

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

        var merges: Set<Merge> = []

        // try merge next and previous
        if let next = await mutableDeadman.nextItem(in: list),
            let previous = await mutableDeadman.previousItem(in: list) {
            merges.insert(await Merge(keeper: next, betweener: mutableDeadman, deadman: previous, in: list))
            merges.insert(await Merge(keeper: previous, betweener: mutableDeadman, deadman: next, in: list))
        }

        // try merge into previous
        if let previous = await mutableDeadman.previousItem(in: list) {
            merges.insert(await Merge(keeper: previous, deadman: mutableDeadman, in: list))
        }

        // try merge into next
        if let next = await mutableDeadman.nextItem(in: list) {
            merges.insert(await Merge(keeper: next, deadman: mutableDeadman, in: list))
        }

        let sortedMerges = merges.sorted { $0.score.rawValue > $1.score.rawValue }

        if TimelineProcessor.debugLogging {
            print("Considering \(merges.count) merges")
            if let bestScore = sortedMerges.first?.score {
                print("Best merge score: \(bestScore)")
            }
        }

        // try the best scoring merge first
        if let winningMerge = sortedMerges.first {
            if let results = await winningMerge.doIt() {
                await processFrom(itemId: results.kept.id)
                return
            }
        }

        if TimelineProcessor.debugLogging {
            print("TimelineProcessor.safeDeleteVisit() failed - no valid merges found")
        }
    }

}
