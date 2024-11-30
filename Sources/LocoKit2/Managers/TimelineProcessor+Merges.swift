//
//  TimelineProcessor+Merges.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 30/11/24.
//

import Foundation

@TimelineActor
extension TimelineProcessor {

    // MARK: - Merge collating

    static func collectPotentialMerges(for list: TimelineLinkedList) async throws -> [Merge] {
        var merges: Set<Merge> = []

        for await workingItem in list where !workingItem.deleted {
            if shouldStopCollecting(merges) {
                break
            }

            await collectAdjacentMerges(for: workingItem, in: list, into: &merges)
            try await collectBetweenerMerges(for: workingItem, in: list, into: &merges)
            try await collectBridgeMerges(for: workingItem, in: list, into: &merges)
        }

        return Array(merges)
    }

    static let maximumPotentialMergesInProcessingLoop = 10

    private static func shouldStopCollecting(_ merges: Set<Merge>) -> Bool {
        let validMerges = merges.count { $0.score != .impossible }
        return validMerges >= maximumPotentialMergesInProcessingLoop
    }

    private static func collectAdjacentMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async {
        if let next = await item.nextItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: next, in: list))
            merges.insert(await Merge(keeper: next, deadman: item, in: list))
        }

        if let previous = await item.previousItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: previous, in: list))
            merges.insert(await Merge(keeper: previous, deadman: item, in: list))
        }
    }

    private static func collectBetweenerMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async throws {
        if let next = await item.nextItem(in: list), try !item.isDataGap, try next.keepnessScore < item.keepnessScore {
            if let nextNext = await next.nextItem(in: list), try !nextNext.isDataGap, try nextNext.keepnessScore > next.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: next, deadman: nextNext, in: list))
                merges.insert(await Merge(keeper: nextNext, betweener: next, deadman: item, in: list))
            }
        }

        if let previous = await item.previousItem(in: list), try !item.isDataGap, try previous.keepnessScore < item.keepnessScore {
            if let prevPrev = await previous.previousItem(in: list), try !prevPrev.isDataGap, try prevPrev.keepnessScore > previous.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: previous, deadman: prevPrev, in: list))
                merges.insert(await Merge(keeper: prevPrev, betweener: previous, deadman: item, in: list))
            }
        }
    }

    private static func collectBridgeMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async throws {
        guard let previous = await item.previousItem(in: list),
              let next = await item.nextItem(in: list),
              previous.source == item.source,
              next.source == item.source,
              try previous.keepnessScore > item.keepnessScore,
              try next.keepnessScore > item.keepnessScore,
              try !previous.isDataGap,
              try !next.isDataGap
        else {
            return
        }

        merges.insert(await Merge(keeper: previous, betweener: item, deadman: next, in: list))
        merges.insert(await Merge(keeper: next, betweener: item, deadman: previous, in: list))
    }

    // MARK: - Item deletion

    public static func safeDelete(_ deadman: TimelineItem) async {
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
