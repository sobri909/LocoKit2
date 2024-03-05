//
//  ActivityBrain.swift
//  
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import CoreLocation


class ActivityBrain {
    let newKalman = KalmanFilter()
    let oldKalman = KalmanCoordinates(qMetresPerSecond: 4)
    let stationaryBrain = StationaryStateDetector()

    func add(location: CLLocation) async -> (lastKnown: MovingStateDetails?, current: MovingStateDetails) {
        newKalman.add(location: location)
        oldKalman.add(location: location)
        
        let kalmanLocation = newKalman.currentEstimatedLocation()
        let currentState = await stationaryBrain.addSample(location: kalmanLocation)
        let lastKnownState = await stationaryBrain.lastKnownState
        return (lastKnownState, currentState)
    }
}

public enum MovingState: Int, Codable {
    case uncertain  = -1
    case stationary = 0
    case moving     = 1

    public var stringValue: String {
        switch self {
        case .uncertain:  return "uncertain"
        case .stationary: return "stationary"
        case .moving:     return "moving"
        }
    }
}

public struct MovingStateDetails {
    public let movingState: MovingState
    public let n: Int
    public let timestamp: Date
    public let duration: TimeInterval
    public let meanAccuracy: CLLocationAccuracy?
    public let weightedMeanSpeed: CLLocationSpeed?
    public let weightedStdDev: CLLocationSpeed?

    internal init(_ movingState: MovingState, n: Int, timestamp: Date = .now, duration: TimeInterval, meanAccuracy: CLLocationAccuracy? = nil, weightedMeanSpeed: CLLocationSpeed? = nil, weightedStdDev: CLLocationSpeed? = nil) {
        self.movingState = movingState
        self.n = n
        self.timestamp = timestamp
        self.duration = duration
        self.meanAccuracy = meanAccuracy
        self.weightedMeanSpeed = weightedMeanSpeed
        self.weightedStdDev = weightedStdDev
    }
}

actor StationaryStateDetector {
    private let targetTimeWindow: TimeInterval = 10.0 // Target time window duration in seconds
    private let maxAllowedDuration: TimeInterval = 60.0 // Maximum allowed duration between samples
    private let accuracyThreshold: CLLocationAccuracy = 50.0 // Accuracy threshold in meters
    private let minSampleCount: Int = 3 // Minimum number of samples required for calculations

    private var sampleBuffer: [CLLocation] = []

    private(set) var lastKnownState: MovingStateDetails?

    func addSample(location: CLLocation) -> MovingStateDetails {
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
            print("determineStationaryState() n: \(n) < minSampleCount")
            return MovingStateDetails(.uncertain, n: n, duration: 0)
        }

        // Calculate the time difference between the oldest and newest samples
        let oldestTimestamp = sampleBuffer.first!.timestamp
        let duration = currentTimestamp.timeIntervalSince(oldestTimestamp)

        // Check if the time difference exceeds the maximum allowed duration
        guard duration <= maxAllowedDuration else {
            print("determineStationaryState() duration: \(duration) > maxAllowedDuration")
            return MovingStateDetails(.uncertain, n: n, duration: duration)
        }

        // Calculate the mean accuracy of the samples in the buffer
        let meanAccuracy = sampleBuffer.map { $0.horizontalAccuracy }.reduce(0, +) / Double(sampleBuffer.count)

        // Check if the mean accuracy is within the acceptable threshold
        guard meanAccuracy <= accuracyThreshold else {
            print("determineStationaryState() meanAccuracy: \(meanAccuracy) > accuracyThreshold")
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
