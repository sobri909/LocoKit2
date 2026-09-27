//
//  TimelineItem+Pruning.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 23/12/2024.
//

import Foundation
import CoreLocation

extension TimelineItem {

    /// Returns the surviving samples, in date order, when anything was deleted; nil when the
    /// item was already pruned. BIG-790: the caller holds this item's loaded samples and hands
    /// the survivors back to them, so nothing built from the arrays (Confirm, the segments list)
    /// can touch a deleted row before the next refetch. The delete itself marks the item via the
    /// `LocomotionSample_AFTER_DELETE_timelineItemId` trigger.
    @TimelineActor
    public func pruneSamples() async throws -> [LocomotionSample]? {
        if isVisit {
            return try await pruneVisitSamples()
        } else {
            return try await pruneTripSamples()
        }
    }

    @TimelineActor
    public func pruneTripSamples() async throws -> [LocomotionSample]? {
        guard isTrip, let trip = trip, let samples else {
            throw TimelineError.invalidItem("Can only prune Trips with samples")
        }
        guard let activityType = trip.activityType else {
            throw TimelineError.invalidItem("Trip requires activityType for pruning")
        }

        let (maxInterval, epsilon): (TimeInterval, CLLocationDistance)
        if ActivityType.workoutTypes.contains(activityType) {
            (maxInterval, epsilon) = (2.0, 2.0) // workout types
        } else if activityType == .airplane {
            (maxInterval, epsilon) = (15.0, 100.0) // airplane
        } else {
            (maxInterval, epsilon) = (6.0, 3.0) // default case (vehicles)
        }

        let sortedSamples = samples.sorted { $0.date < $1.date }
        let points = sortedSamples.enumerated().compactMap { index, sample -> (coordinate: CLLocationCoordinate2D, date: Date, index: Int)? in
            guard let coordinate = sample.coordinate, coordinate.isUsable else { return nil }
            return (coordinate, sample.date, index)
        }

        guard points.count > 2 else { return nil }

        let keepIndices = PathSimplifier.simplify(coordinates: points, maxInterval: maxInterval, epsilon: epsilon)
        guard keepIndices.count < sortedSamples.count else { return nil }

        try await Database.pool.write { db in
            for (index, sample) in sortedSamples.enumerated() {
                if !keepIndices.contains(index) {
                    try sample.delete(db)
                }
            }
        }

        let survivors = keepIndices.sorted().map { sortedSamples[$0] }
        var maxGapSeconds: TimeInterval = 0
        for i in 1..<survivors.count {
            let gap = survivors[i].date.timeIntervalSince(survivors[i-1].date)
            if gap > maxGapSeconds { maxGapSeconds = gap }
        }
        Log.info("pruneTripSamples() \(debugShortId): \(keepIndices.count)/\(sortedSamples.count) samples (\(activityType.displayName)), maxGap: \(String(format: "%.0f", maxGapSeconds))s", subsystem: .timeline)
        return survivors
    }

    // MARK: - Visit pruning

    /// Prune visit samples using a sliding window of three consecutive samples.
    ///
    /// For each window where the span (first to last) is <= maxGap:
    /// - Delete the middle sample unless it has strictly the best accuracy of the three.
    /// - Repeat until no more deletions occur (stable).
    ///
    /// This guarantees:
    /// - No gap > maxGap is ever created (the two ends are already within maxGap)
    /// - Higher accuracy samples are preferentially retained
    /// - Idempotent: re-running on already-pruned data produces no changes
    @TimelineActor
    private func pruneVisitSamples() async throws -> [LocomotionSample]? {
        guard isVisit, let dateRange = dateRange, let samples = samples else {
            throw TimelineError.invalidItem("Can only prune Visits with samples")
        }
        guard samples.count > 2 else { return nil }

        let startEdgeEnd = dateRange.start + .minutes(20)
        let endEdgeStart = dateRange.end - .minutes(20)
        let maxGap: TimeInterval = .minutes(3)

        // protect edge and non-stationary samples from deletion
        var protected: Set<String> = []
        for sample in samples {
            if sample.activityType != .stationary && sample.activityType != .bogus {
                protected.insert(sample.id)
            } else if sample.date <= startEdgeEnd || sample.date >= endEdgeStart {
                protected.insert(sample.id)
            }
        }

        var working = samples.sorted { $0.date < $1.date }
        var totalDeleted = 0

        while true {
            var deletedThisPass = 0
            var i = 0

            while i < working.count - 2 {
                let left = working[i]
                let mid = working[i + 1]
                let right = working[i + 2]

                // skip protected samples
                if protected.contains(mid.id) {
                    i += 1
                    continue
                }

                let span = right.date.timeIntervalSince(left.date)
                if span <= maxGap {
                    let midAcc = mid.horizontalAccuracy ?? 999
                    let leftAcc = left.horizontalAccuracy ?? 999
                    let rightAcc = right.horizontalAccuracy ?? 999

                    // delete middle unless it's strictly the best accuracy
                    if midAcc >= min(leftAcc, rightAcc) {
                        working.remove(at: i + 1)
                        deletedThisPass += 1
                        continue
                    }
                }

                i += 1
            }

            totalDeleted += deletedThisPass
            if deletedThisPass == 0 { break }
        }

        // log results
        var maxGapSeconds: TimeInterval = 0
        for i in 1..<working.count {
            let gap = working[i].date.timeIntervalSince(working[i-1].date)
            if gap > maxGapSeconds { maxGapSeconds = gap }
        }
        if totalDeleted > 0 {
            Log.info("pruneVisitSamples() \(debugShortId): \(working.count)/\(samples.count) samples, maxGap: \(String(format: "%.0f", maxGapSeconds))s (\(totalDeleted) deleted)", subsystem: .timeline)
        } else {
            Log.debug("pruneVisitSamples() \(debugShortId): \(working.count) samples, maxGap: \(String(format: "%.0f", maxGapSeconds))s (no change)", subsystem: .timeline)
        }

        if totalDeleted == 0 { return nil }

        // delete pruned samples from the database
        let survivorIds = Set(working.map { $0.id })
        try await Database.pool.write { [survivorIds] db in
            for sample in samples {
                if !survivorIds.contains(sample.id) {
                    try sample.delete(db)
                }
            }
        }
        return working
    }

}
