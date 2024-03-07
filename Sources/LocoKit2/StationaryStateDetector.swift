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
    private let maxAllowedDuration: TimeInterval = 60.0 // Maximum allowed duration between samples
    private let accuracyThreshold: CLLocationAccuracy = 50.0 // Accuracy threshold in meters
    private let minSampleCount: Int = 3 // Minimum number of samples required for calculations

    private var sampleBuffer: [CLLocation] = []

    private(set) var lastKnownState: MovingStateDetails?

    func add(location: CLLocation) -> MovingStateDetails {
        sampleBuffer.append(location)

        // Remove samples outside the target time window
        while let oldest = sampleBuffer.first, location.timestamp.timeIntervalSince(oldest.timestamp) > targetTimeWindow {
            sampleBuffer.removeFirst()
        }

        return determineStationaryState()
    }

    func determineStationaryState() -> MovingStateDetails {
        let currentTimestamp = Date()

        let n = sampleBuffer.count

        guard n > 0 else {
            return MovingStateDetails(.uncertain, n: n, duration: 0)
        }

        // Check if there are enough samples in the buffer
        guard n >= minSampleCount else {
            return MovingStateDetails(.uncertain, n: n, duration: 0)
        }

        // Calculate the time difference between the oldest and newest samples
        let oldestTimestamp = sampleBuffer.first!.timestamp
        let duration = currentTimestamp.timeIntervalSince(oldestTimestamp)

        // Check if the time difference exceeds the maximum allowed duration
        guard duration <= maxAllowedDuration else {
            return MovingStateDetails(.uncertain, n: n, duration: duration)
        }

        // Calculate the mean accuracy of the samples in the buffer
        let meanAccuracy = sampleBuffer.map { $0.horizontalAccuracy }.reduce(0, +) / Double(sampleBuffer.count)

        // Check if the mean accuracy is within the acceptable threshold
        guard meanAccuracy <= accuracyThreshold else {
            return MovingStateDetails(.uncertain, n: n, duration: duration, meanAccuracy: meanAccuracy)
        }

        // Calculate weighted statistics based on the samples in the buffer
        let speeds = sampleBuffer.map { $0.speed }
        let weights = sampleBuffer.map { 1.0 / $0.horizontalAccuracy }
        let totalWeight = weights.reduce(0, +)
        let weightedSpeeds = zip(speeds, weights).map { $0 * $1 }
        let weightedMeanSpeed = weightedSpeeds.reduce(0, +) / totalWeight
        let weightedSquaredDifferences = zip(speeds, weights).map { pow($0 - weightedMeanSpeed, 2) * $1 }
        let weightedVariance = weightedSquaredDifferences.reduce(0, +) / totalWeight
        let weightedStdDev = sqrt(weightedVariance)

        // Determine the stationary state based on the weighted statistics
        let result: MovingState = (weightedMeanSpeed < 0.5 && weightedStdDev < 0.3) ? .stationary : .moving

        let resultDetails = MovingStateDetails(
            result, n: n, duration: duration,
            meanAccuracy: meanAccuracy,
            weightedMeanSpeed: weightedMeanSpeed,
            weightedStdDev: weightedStdDev
        )

        lastKnownState = resultDetails

        return resultDetails
    }

}
