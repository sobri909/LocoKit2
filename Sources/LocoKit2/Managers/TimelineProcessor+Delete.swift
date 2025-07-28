//
//  TimelineProcessor+Delete.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation

@TimelineActor
extension TimelineProcessor {

    public static func safeDelete(_ deadman: TimelineItem) async {
        guard let handle = await OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineProcessor.safeDelete(_:)",
            objectKey: deadman.id,
            rejectDuplicates: true
        ) else {
            logger.info("Skipping duplicate TimelineProcessor.safeDelete(_:)", subsystem: .timeline)
            return
        }
        
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        if TimelineProcessor.debugLogging {
            print("TimelineProcessor.safeDelete()")
        }

        // get the linked list context for edge finding
        guard let list = await TimelineLinkedList(fromItemId: deadman.id) else { return }

        var merges: Set<Merge> = []

        // try merge next and previous
        if let next = await deadman.nextItem(in: list),
            let previous = await deadman.previousItem(in: list) {
            merges.insert(await Merge(keeper: next, betweener: deadman, deadman: previous, in: list))
            merges.insert(await Merge(keeper: previous, betweener: deadman, deadman: next, in: list))
        }

        // try merge into previous
        if let previous = await deadman.previousItem(in: list) {
            merges.insert(await Merge(keeper: previous, deadman: deadman, in: list))
        }

        // try merge into next
        if let next = await deadman.nextItem(in: list) {
            merges.insert(await Merge(keeper: next, deadman: deadman, in: list))
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
            print("TimelineProcessor.safeDelete() failed - no valid merges found")
        }
    }

}
