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
            (maxInterval, epsilon) = (2.0, 3.0) // workout types
        } else if activityType == .airplane {
            (maxInterval, epsilon) = (15.0, 100.0) // airplane
        } else {
            (maxInterval, epsilon) = (6.0, 4.0) // default case (vehicles)
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

        print("""
          pruneTripSamples() results:
          - Activity type: \(activityType.displayName)
          - Total samples: \(sortedSamples.count)
          - Keeping: \(keepIndices.count) samples (\(Int((Double(keepIndices.count) / Double(sortedSamples.count)) * 100))%)
          """)
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
        var rollingWindow: [LocomotionSample] = []

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

        // rolling window approach
        for sample in middleSamples {
            rollingWindow.append(sample)

            if let windowRange = rollingWindow.dateRange(),
               windowRange.duration >= maxGap {

                // pick best sample from window
                if let bestSample = chooseBestSample(from: rollingWindow) {
                    keepSamples.insert(bestSample.id)

                    // remove everything up to and including kept sample
                    if let keptIndex = rollingWindow.firstIndex(where: { $0.id == bestSample.id }) {
                        rollingWindow.removeFirst(keptIndex + 1)
                    }
                }
            }
        }

        // handle any remaining window
        if !rollingWindow.isEmpty {
            if let bestSample = chooseBestSample(from: rollingWindow) {
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

        print("""
              pruneVisitSamples() results:
              - Total samples: \(samples.count)
              - Keeping \(keepSamples.count) samples (\(Int((Double(keepSamples.count) / Double(samples.count)) * 100))%)
              """)
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
