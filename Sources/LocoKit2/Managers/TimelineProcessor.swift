//
//  TimelineProcessor.swift
//
//
//  Created by Matt Greenfield on 6/6/24.
//

import Foundation
import GRDB

@TimelineActor
public final class TimelineProcessor {

    public static let highlander = TimelineProcessor()

    public static let debugLogging = true
    
    private let maxProcessingListSize = 21
    private let maximumPotentialMergesInProcessingLoop = 10

    public func processFrom(itemId: String) async {
        guard let list = await processingList(fromItemId: itemId) else { return }
        if let results = await process(list) {
            await processFrom(itemId: results.kept.id)
        }
    }

    public func process(_ list: TimelineLinkedList) async -> MergeResult? {
        await sanitiseEdges(for: list)

        let merges = await collectPotentialMerges(for: list)
            .sorted { $0.score.rawValue > $1.score.rawValue }

        // find the highest scoring valid merge
        guard let winningMerge = merges.first, winningMerge.score != .impossible else {
            return nil
        }

        return await winningMerge.doIt()
    }

    // MARK: - Private

    private init() {}

    private func processingList(fromItemId: String) async -> TimelineLinkedList? {
        guard let list = await TimelineLinkedList(fromItemId: fromItemId) else { return nil }

        // collect items before seedItem, up to two keepers
        var previousKeepers = 0
        var workingItem = await list.seedItem
        while previousKeepers < 2, await list.timelineItems.count < maxProcessingListSize, let previous = await workingItem.previousItem(in: list) {
            if previous.isWorthKeeping { previousKeepers += 1 }
            workingItem = previous
        }

        // collect items after seedItem, up to two keepers
        var nextKeepers = 0
        workingItem = await list.seedItem
        while nextKeepers < 2, await list.timelineItems.count < maxProcessingListSize, let next = await workingItem.nextItem(in: list) {
            if next.isWorthKeeping { nextKeepers += 1 }
            workingItem = next
        }

        return list
    }

    // MARK: - Merge collating

    private func collectPotentialMerges(for list: TimelineLinkedList) async -> [Merge] {
        var merges: Set<Merge> = []
        let items = await list.timelineItems.values

        for workingItem in items {
            if shouldStopCollecting(merges) {
                break
            }

            await collectAdjacentMerges(for: workingItem, in: list, into: &merges)
            await collectBetweenerMerges(for: workingItem, in: list, into: &merges)
            await collectBridgeMerges(for: workingItem, in: list, into: &merges)
        }

        return Array(merges)
    }

    private func shouldStopCollecting(_ merges: Set<Merge>) -> Bool {
        merges.count >= maximumPotentialMergesInProcessingLoop && merges.first(where: { $0.score != .impossible }) != nil
    }

    private func collectAdjacentMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async {
        if let next = await item.nextItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: next, in: list))
            merges.insert(await Merge(keeper: next, deadman: item, in: list))
        }

        if let previous = await item.previousItem(in: list) {
            merges.insert(await Merge(keeper: item, deadman: previous, in: list))
            merges.insert(await Merge(keeper: previous, deadman: item, in: list))
        }
    }

    private func collectBetweenerMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async {
        if let next = await item.nextItem(in: list), !item.isDataGap, next.keepnessScore < item.keepnessScore {
            if let nextNext = await next.nextItem(in: list), !nextNext.isDataGap, nextNext.keepnessScore > next.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: next, deadman: nextNext, in: list))
                merges.insert(await Merge(keeper: nextNext, betweener: next, deadman: item, in: list))
            }
        }

        if let previous = await item.previousItem(in: list), !item.isDataGap, previous.keepnessScore < item.keepnessScore {
            if let prevPrev = await previous.previousItem(in: list), !prevPrev.isDataGap, prevPrev.keepnessScore > previous.keepnessScore {
                merges.insert(await Merge(keeper: item, betweener: previous, deadman: prevPrev, in: list))
                merges.insert(await Merge(keeper: prevPrev, betweener: previous, deadman: item, in: list))
            }
        }
    }

    private func collectBridgeMerges(for item: TimelineItem, in list: TimelineLinkedList, into merges: inout Set<Merge>) async {
        guard let previous = await item.previousItem(in: list),
              let next = await item.nextItem(in: list),
              previous.source == item.source,
              next.source == item.source,
              previous.keepnessScore > item.keepnessScore,
              next.keepnessScore > item.keepnessScore,
              !previous.isDataGap,
              !next.isDataGap
        else {
            return
        }

        merges.insert(await Merge(keeper: previous, betweener: item, deadman: next, in: list))
        merges.insert(await Merge(keeper: next, betweener: item, deadman: previous, in: list))
    }

    // MARK: - Edge cleansing

    private var lastCleansedSamples: Set<LocomotionSample> = []

    private func sanitiseEdges(for list: TimelineLinkedList) async {
        let items = Array(await list.timelineItems.values)
        var allMoved: Set<LocomotionSample> = []

        for item in items {
            let moved = await item.sanitiseEdges(in: list, excluding: lastCleansedSamples)
            allMoved.formUnion(moved)
        }

        if TimelineProcessor.debugLogging, !allMoved.isEmpty {
            logger.debug("Moved \(allMoved.count) samples between item edges")
        }

        // Update lastCleansedSamples for the next processing cycle
        lastCleansedSamples = allMoved
    }

}
