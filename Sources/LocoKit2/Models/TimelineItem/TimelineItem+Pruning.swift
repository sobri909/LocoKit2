//
//  TimelineItem+Pruning.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 23/12/2024.
//

import Foundation
import CoreLocation

extension TimelineItem {

    @TimelineActor
    public func pruneSamples() async throws {
        if isVisit {
            try await pruneVisitSamples()
        } else {
            try await pruneTripSamples()
        }
    }

    @TimelineActor
    public func pruneTripSamples() async throws {
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

        guard points.count > 2 else { return }

        let keepIndices = PathSimplifier.simplify(coordinates: points, maxInterval: maxInterval, epsilon: epsilon)

        try await Database.pool.write { db in
            for (index, sample) in sortedSamples.enumerated() {
                if !keepIndices.contains(index) {
                    try sample.delete(db)
                }
            }
        }

        if keepIndices.count < sortedSamples.count {
            let survivors = keepIndices.sorted().map { sortedSamples[$0] }
            var maxGapSeconds: TimeInterval = 0
            for i in 1..<survivors.count {
                let gap = survivors[i].date.timeIntervalSince(survivors[i-1].date)
                if gap > maxGapSeconds { maxGapSeconds = gap }
            }
            Log.info("pruneTripSamples() \(debugShortId): \(keepIndices.count)/\(sortedSamples.count) samples (\(activityType.displayName)), maxGap: \(String(format: "%.0f", maxGapSeconds))s", subsystem: .timeline)
        }
    }

    @TimelineActor
    private func pruneVisitSamples() async throws {
        guard isVisit, let dateRange = dateRange, let samples = samples else {
            throw TimelineError.invalidItem("Can only prune Visits with samples")
        }

        let startEdgeEnd = dateRange.start + .minutes(30)
        let endEdgeStart = dateRange.end - .minutes(30)
        let maxGap: TimeInterval = .minutes(2)

        var keepSamples: Set<String> = []

        // first pass: keep all edge and non-stationary samples
        for sample in samples {
            // Always keep non-stationary samples
            if sample.activityType != .stationary {
                keepSamples.insert(sample.id)
                continue
            }

            // Keep edge samples
            if sample.date <= startEdgeEnd || sample.date >= endEdgeStart {
                keepSamples.insert(sample.id)
                continue
            }
        }

        // get remaining samples to process
        let middleSamples = samples
            .filter { !keepSamples.contains($0.id) }
            .sorted { $0.date < $1.date }

        // group nearby samples, keep the best from each group
        let clusters = clusterByProximity(middleSamples, maxGap: maxGap)
        for cluster in clusters {
            if cluster.count == 1 {
                keepSamples.insert(cluster[0].id)
            } else if let bestSample = chooseBestSample(from: cluster) {
                keepSamples.insert(bestSample.id)
            }
        }

        // delete samples not in keepSamples
        try await Database.pool.write { [keepSamples] db in
            for sample in samples {
                if !keepSamples.contains(sample.id) {
                    try sample.delete(db)
                }
            }
        }

        if keepSamples.count < samples.count {
            let survivors = samples.filter { keepSamples.contains($0.id) }.sorted { $0.date < $1.date }
            var maxGapSeconds: TimeInterval = 0
            for i in 1..<survivors.count {
                let gap = survivors[i].date.timeIntervalSince(survivors[i-1].date)
                if gap > maxGapSeconds { maxGapSeconds = gap }
            }
            Log.info("pruneVisitSamples() \(debugShortId): \(keepSamples.count)/\(samples.count) samples, maxGap: \(String(format: "%.0f", maxGapSeconds))s", subsystem: .timeline)
        }
    }

    /// Groups consecutive samples into time windows of at most maxGap duration.
    /// A new cluster starts when either:
    /// - the gap to the next sample is >= maxGap (sparse data boundary)
    /// - the cluster's total duration would exceed maxGap (dense data window cap)
    /// Input must be sorted by date.
    private func clusterByProximity(_ samples: [LocomotionSample], maxGap: TimeInterval) -> [[LocomotionSample]] {
        guard !samples.isEmpty else { return [] }

        var clusters: [[LocomotionSample]] = []
        var current: [LocomotionSample] = [samples[0]]

        for sample in samples.dropFirst() {
            let clusterStart = current[0].date
            let wouldSpan = sample.date.timeIntervalSince(clusterStart)

            if wouldSpan >= maxGap {
                // cluster would exceed maxGap — close it and start fresh
                clusters.append(current)
                current = [sample]
            } else {
                current.append(sample)
            }
        }
        clusters.append(current)

        return clusters
    }

    private func chooseBestSample(from candidates: [LocomotionSample]) -> LocomotionSample? {
        guard !candidates.isEmpty else { return nil }

        // Sort by accuracy (higher accuracy = lower number = better)
        // For equal accuracies, prefer older samples to minimize gaps
        // Samples without horizontalAccuracy go last
        return candidates
            .sorted { lhs, rhs in
                guard let lhsAccuracy = lhs.horizontalAccuracy else { return false }
                guard let rhsAccuracy = rhs.horizontalAccuracy else { return true }

                if lhsAccuracy == rhsAccuracy {
                    return lhs.date < rhs.date // older samples first
                }
                return lhsAccuracy < rhsAccuracy
            }
            .first
    }
    
}
