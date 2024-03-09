//
//  StationaryStateDetector.swift
//  
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import CoreLocation

actor StationaryStateDetector {

    private let targetTimeWindow: TimeInterval = 10.0 // Target time window duration in seconds
    private let accuracyThreshold: CLLocationAccuracy = 50.0 // Accuracy threshold in meters
    private let meanSpeedThreshold: CLLocationSpeed = 0.5
    private let sdSpeedThreshold: CLLocationSpeed = 0.3

    private(set) var lastKnownState: MovingStateDetails?

    func add(location: CLLocation) -> MovingStateDetails {
        sample.append(location)

        let result = determineStationaryState()
        scheduleUpdate()
        return result
    }

    func freeze() {
        frozen = true
    }

    func unfreeze() {
        frozen = false
        scheduleUpdate()
    }

    // MARK: - Private

    private var sample: [CLLocation] = []
    private var frozen: Bool = false

    private func scheduleUpdate() {
        if frozen { return }

        print("scheduleUpdate()")

        Task {
            try? await Task.sleep(for: .seconds(2))
            determineStationaryState()
            scheduleUpdate()
        }
    }

    @discardableResult
    private func determineStationaryState() -> MovingStateDetails {
        guard let newest = sample.last else {
            return MovingStateDetails(.uncertain, n: 0, timestamp: .now, duration: 0)
        }

        print("determineStationaryState()")

        // Remove samples outside the target time window
        while sample.count > 1, let oldest = sample.first, newest.timestamp.timeIntervalSince(oldest.timestamp) > targetTimeWindow {
            sample.removeFirst()
        }

        let n = sample.count

        if n == 1 {
            let result: MovingState = (newest.speed < meanSpeedThreshold + sdSpeedThreshold) ? .stationary : .moving
            return MovingStateDetails(result, n: 1, timestamp: newest.timestamp, duration: 0, meanSpeed: newest.speed)
        }

        let duration = newest.timestamp.timeIntervalSince(sample.first!.timestamp)

        // Calculate the mean accuracy of the samples in the buffer
        let meanAccuracy = sample.map { $0.horizontalAccuracy }.reduce(0, +) / Double(sample.count)

        // Check if the mean accuracy is within the acceptable threshold
        guard meanAccuracy <= accuracyThreshold else {
            return MovingStateDetails(.uncertain, n: n, timestamp: newest.timestamp, duration: duration, meanAccuracy: meanAccuracy)
        }

        // Calculate weighted statistics based on the samples in the buffer
        let speeds = sample.map { $0.speed }
        let weights = sample.map { 1.0 / $0.horizontalAccuracy }
        let totalWeight = weights.reduce(0, +)
        let weightedSpeeds = zip(speeds, weights).map { $0 * $1 }
        let weightedMeanSpeed = weightedSpeeds.reduce(0, +) / totalWeight
        let weightedSquaredDifferences = zip(speeds, weights).map { pow($0 - weightedMeanSpeed, 2) * $1 }
        let weightedVariance = weightedSquaredDifferences.reduce(0, +) / totalWeight
        let weightedStdDev = sqrt(weightedVariance)

        // Determine the stationary state based on the weighted statistics
        let result: MovingState = (weightedMeanSpeed < meanSpeedThreshold && sdSpeedThreshold < 0.3) ? .stationary : .moving

        let resultDetails = MovingStateDetails(
            result, n: n,
            timestamp: newest.timestamp,
            duration: duration,
            meanAccuracy: meanAccuracy,
            meanSpeed: weightedMeanSpeed,
            sdSpeed: weightedStdDev
        )

        lastKnownState = resultDetails

        return resultDetails
    }

}
