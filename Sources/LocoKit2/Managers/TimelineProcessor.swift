//
//  TimelineProcessor.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 6/6/24.
//

import Foundation
import CoreLocation
import GRDB

@TimelineActor
public enum TimelineProcessor {

    public static let maximumModeShiftSpeed = CLLocationSpeed(kmh: 2)

    private static let maxProcessingListSize = 21

    public static func processFrom(itemId: String) async {
        let handle = await OperationRegistry.startOperation(.timeline, operation: "processFrom(itemId:)", objectKey: itemId)
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        do {
            if let list = try await processingList(fromItemId: itemId) {
                await process(list)
            }
        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

    public static func process(_ items: [TimelineItem]) async {
        let handle = await OperationRegistry.startOperation(.timeline, operation: "process([TimelineItem]) [\(items.count)]")
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        let list = await TimelineLinkedList(fromItems: items)
        await process(list)
    }

    public static func process(itemIds: [String]) async {
        let handle = await OperationRegistry.startOperation(.timeline, operation: "process(itemIds:) [\(itemIds.count)]")
        defer { Task { await OperationRegistry.endOperation(handle) } }
        
        let list = await TimelineLinkedList(fromItemIds: itemIds)
        await process(list)
    }

    public static func process(_ list: TimelineLinkedList) async {
        var lastResult: MergeResult?
        do {
            while true {
                try await sanitiseEdges(for: list)

                // heal broken edges for items in the list
                for itemId in await list.itemIds {
                    try await healEdges(itemId: itemId)
                }

                let merges = try await collectPotentialMerges(for: list)
                    .sorted { $0.score.rawValue > $1.score.rawValue }

                if TimelineProcessor.debugLogging {
                    if merges.isEmpty {
                        logger.info("Considering 0 merges", subsystem: .timeline)
                    } else {
                        logger.info("Considering \(merges.count) merges", subsystem: .timeline)
//                        do {
//                            let descriptions = try merges.map { try $0.description }.joined(separator: "\n")
//                            print("Considering \(merges.count) merges:\n\(descriptions)")
//                        } catch {
//                            logger.error(error, subsystem: .timeline)
//                        }
                    }
                }

                // Find the highest scoring valid merge
                guard let winningMerge = merges.first, winningMerge.score != .impossible else {
                    break
                }

                lastResult = await winningMerge.doIt()

                // might've deleted current item
                TimelineRecorder.updateCurrentItemId()

                if let lastResult {
                    list.invalidate(itemId: lastResult.kept.id)
                    for killed in lastResult.killed {
                        list.invalidate(itemId: killed.id)
                    }
                }
            }

        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

    private static func processingList(fromItemId: String) async throws -> TimelineLinkedList? {
        guard let list = await TimelineLinkedList(fromItemId: fromItemId) else { return nil }
        guard let seedItem = list.seedItem else { return nil }

        // collect items before seedItem, up to two keepers
        var previousKeepers = 0
        var workingItem = seedItem
        while previousKeepers < 2, list.count < maxProcessingListSize, let previous = await workingItem.previousItem(in: list) {
            if try previous.isWorthKeeping { previousKeepers += 1 }
            workingItem = previous
        }

        // collect items after seedItem, up to two keepers
        var nextKeepers = 0
        workingItem = seedItem
        while nextKeepers < 2, list.count < maxProcessingListSize, let next = await workingItem.nextItem(in: list) {
            if try next.isWorthKeeping { nextKeepers += 1 }
            workingItem = next
        }

        return list
    }


    // MARK: - Debug Logging

    public private(set) static var debugLogging = false

    nonisolated
    public static func enableDebugLogging() {
        Task { @TimelineActor in
            debugLogging = true
        }
    }

    nonisolated
    public static func disableDebugLogging() {
        Task { @TimelineActor in
            debugLogging = false
        }
    }

}
