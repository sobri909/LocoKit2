//
//  SampleImportProcessor.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-06
//

import Foundation
import GRDB

// MARK: - Result Types

public struct SampleBatchResult: Sendable {
    public var orphans: [String: [LocomotionSample]]
    public var scenario2: [String: [LocomotionSample]]
    public var orphanCount: Int
    public var scenario1Count: Int
    public var scenario2Count: Int

    public init() {
        self.orphans = [:]
        self.scenario2 = [:]
        self.orphanCount = 0
        self.scenario1Count = 0
        self.scenario2Count = 0
    }
}

// MARK: -

public enum SampleImportProcessor {

    /// Process a batch of samples, handling disabled state mismatches and orphan detection.
    ///
    /// - Parameters:
    ///   - samples: The samples to process
    ///   - validItemIds: Set of valid timeline item IDs (samples referencing other IDs are orphaned)
    ///   - itemDisabledStates: Map of item ID to disabled state for mismatch detection
    ///   - orphanOnlyIfEnabled: If true, only treat samples as orphans if they're not disabled (OldLocoKitImporter behavior)
    ///   - db: Database connection for insertion
    /// - Returns: Batch result with orphans, scenario2 samples, and counts
    public static func processBatch(
        samples: [LocomotionSample],
        validItemIds: Set<String>,
        itemDisabledStates: [String: Bool],
        orphanOnlyIfEnabled: Bool = false,
        db: GRDB.Database
    ) throws -> SampleBatchResult {
        var result = SampleBatchResult()

        for var sample in samples {
            var scenario2Key: String?
            var orphanKey: String?

            // check for disabled state mismatches
            if let itemId = sample.timelineItemId, let itemDisabled = itemDisabledStates[itemId] {
                if itemDisabled && !sample.disabled {
                    // scenario 1: item disabled, sample enabled → force sample to disabled
                    sample.disabled = true
                    result.scenario1Count += 1

                } else if !itemDisabled && sample.disabled {
                    // scenario 2: item enabled, sample disabled → preserved parent candidate
                    scenario2Key = itemId
                    // orphan from current parent (will be reassigned to preserved parent later)
                    sample.timelineItemId = nil
                }
            }

            // check for orphaned samples (references to missing items)
            if let originalItemId = sample.timelineItemId, !validItemIds.contains(originalItemId) {
                // optionally skip disabled samples for orphan collection (legacy import behavior)
                if !orphanOnlyIfEnabled || !sample.disabled {
                    orphanKey = originalItemId
                }

                // always null the reference for database compliance
                sample.timelineItemId = nil
            }

            try sample.insert(db, onConflict: .ignore)

            // BIG-629: only newly-inserted samples join the rebuild collections. An .ignore'd
            // no-op means the sample already exists in the main db with its own current home —
            // a re-run must not yank it into a freshly-created parent.
            guard db.changesCount == 1 else { continue }

            if let scenario2Key {
                result.scenario2[scenario2Key, default: []].append(sample)
                result.scenario2Count += 1
            }
            if let orphanKey {
                result.orphans[orphanKey, default: []].append(sample)
                result.orphanCount += 1
            }
        }

        return result
    }

    /// Log batch results if there were any issues found.
    public static func logBatchResults(_ result: SampleBatchResult) {
        if result.orphanCount > 0 {
            Log.error("Orphaned \(result.orphanCount) samples with missing parent items", subsystem: .importing)
        }
        if result.scenario1Count > 0 {
            Log.info("Normalized \(result.scenario1Count) samples (scenario 1: item.disabled=true, sample.disabled=false)", subsystem: .importing)
        }
        if result.scenario2Count > 0 {
            Log.info("Collected \(result.scenario2Count) samples for preserved parent creation (scenario 2: item.disabled=false, sample.disabled=true)", subsystem: .importing)
        }
    }

    /// Merge batch results into accumulated collections.
    public static func mergeResults(
        _ batchResult: SampleBatchResult,
        into orphans: inout [String: [LocomotionSample]],
        scenario2: inout [String: [LocomotionSample]]
    ) {
        for (itemId, samples) in batchResult.orphans {
            orphans[itemId, default: []].append(contentsOf: samples)
        }
        for (itemId, samples) in batchResult.scenario2 {
            scenario2[itemId, default: []].append(contentsOf: samples)
        }
    }
}
