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
        do {
            if let list = try await processingList(fromItemId: itemId) {
                await process(list)
            }
        } catch {
            Log.error(error, subsystem: .timeline)
        }
    }

    public static func process(items: [TimelineItem]) async {
        let list = await TimelineLinkedList(fromItems: items)
        await process(list)
    }

    public static func process(itemIds: [String]) async {
        let list = await TimelineLinkedList(fromItemIds: itemIds)
        await process(list)
    }

    public static func process(_ list: TimelineLinkedList) async {
        // block processing during partial import to prevent corruption
        do {
            try await ImportState.guardNotPartialImport()
        } catch {
            Log.info("TimelineProcessor blocked by partial import", subsystem: .timeline)
            return
        }

        let itemIds = list.itemIds
        let objectKey = Set(itemIds).hashValue.description
        
        guard let handle = OperationRegistry.startOperation(
            .timeline,
            operation: "TimelineProcessor.process(list:)",
            objectKey: objectKey,
            rejectDuplicates: true
        ) else {
            Log.debug("Skipping duplicate TimelineProcessor.process(list:)", subsystem: .timeline)
            return
        }

        defer { OperationRegistry.endOperation(handle) }
        
        // BIG-752: the belt and the no-repeat set. A merge whose write is refused twice sits out the rest
        // of this call, and three iterations in a row without a merge end the call with one error line,
        // where the loop used to retry a refused write against the same cached list without limit.
        var failures: [String: Int] = [:]
        var noProgress = 0
        do {
            processing: while true {
                try await sanitiseEdges(for: list)

                // heal broken edges for items in the list
                for itemId in list.itemIds {
                    do {
                        try await healEdges(itemId: itemId)
                    } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                        Log.debug("Edge healing constraint error (harmless): \(error)", subsystem: .timeline)
                    }
                }

                let merges = try await collectPotentialMerges(for: list)
                    .filter { (failures[$0.key] ?? 0) < 2 }
                    .sorted { $0.score.rawValue > $1.score.rawValue }

                if TimelineProcessor.debugLogging {
                    if merges.isEmpty {
                        Log.info("Considering 0 merges", subsystem: .timeline)
                    } else {
                        Log.info("Considering \(merges.count) merges", subsystem: .timeline)
//                        do {
//                            let descriptions = try merges.map { try $0.description }.joined(separator: "\n")
//                            print("Considering \(merges.count) merges:\n\(descriptions)")
//                        } catch {
//                            Log.error(error, subsystem: .timeline)
//                        }
                    }
                }

                // Find the highest scoring valid merge
                guard let winningMerge = merges.first, winningMerge.score != .impossible else {
                    break
                }

                let outcome = await winningMerge.doIt()

                // might've deleted current item
                TimelineRecorder.updateCurrentItemId()

                switch outcome {
                case .merged(let result):
                    noProgress = 0
                    list.invalidate(itemId: result.kept.id)
                    for killed in result.killed {
                        list.invalidate(itemId: killed.id)
                    }
                    // the keeper's neighbours were rewired by the edge triggers; their cached copies are
                    // stale, and the next merge may inherit from them (BIG-752)
                    for neighbourId in [result.kept.base.previousItemId, result.kept.base.nextItemId].compactMap({ $0 }) {
                        list.invalidate(itemId: neighbourId)
                    }
                case .notValid:
                    noProgress += 1
                    invalidate(winningMerge, in: list)
                case .failed:
                    noProgress += 1
                    failures[winningMerge.key, default: 0] += 1
                    invalidate(winningMerge, in: list)
                case .blocked:
                    break processing
                }

                if noProgress >= 3 {
                    let betweener = winningMerge.betweener.map { ", betweener \($0.debugShortId)" } ?? ""
                    let line = "TimelineProcessor.process: no progress after \(noProgress) attempts; stopping this call. last merge: keeper \(winningMerge.keeper.debugShortId), deadman \(winningMerge.deadman.debugShortId)\(betweener)"
                    // a refused write is the fault this belt exists for; three not-valid results in a row are
                    // concurrent churn (another call on an overlapping list), worth a line but not an error
                    if failures.isEmpty {
                        Log.info(line, subsystem: .timeline)
                    } else {
                        Log.error(line, subsystem: .timeline)
                    }
                    break processing
                }
            }

        } catch {
            Log.error(error, subsystem: .timeline)
        }
    }

    /// The three items of a merge that did not apply are re-read from the database on the next
    /// iteration (BIG-752).
    private static func invalidate(_ merge: Merge, in list: TimelineLinkedList) {
        list.invalidate(itemId: merge.keeper.id)
        list.invalidate(itemId: merge.deadman.id)
        if let betweener = merge.betweener {
            list.invalidate(itemId: betweener.id)
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
