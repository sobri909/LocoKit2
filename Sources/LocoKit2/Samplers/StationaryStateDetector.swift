//
//  StationaryStateDetector.swift
//  
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import CoreLocation

public actor StationaryStateDetector {

    private let targetTimeWindow: TimeInterval = 10.0
    private let accuracyThreshold: CLLocationAccuracy = 50.0
    private let meanSpeedThreshold: CLLocationSpeed = 0.5
    private let sdSpeedThreshold: CLLocationSpeed = 0.3
    private let rawSpeedInvalidThreshold: Double = 0.5

    private var sample: [CLLocation] = []
    private var rawSample: [CLLocation] = []

    public init() {}

    public func add(location: CLLocation) {
        sample.append(location)
        sample.sort { $0.timestamp < $1.timestamp }
    }

    public func addRaw(location: CLLocation) {
        rawSample.append(location)
        rawSample.sort { $0.timestamp < $1.timestamp }
    }

    public func currentState() -> MovingStateDetails {
        guard let newest = sample.last else {
            return MovingStateDetails(.uncertain, n: 0, timestamp: .now)
        }

        // Remove samples outside the target time window
        while sample.count > 1, let oldest = sample.first, newest.timestamp.timeIntervalSince(oldest.timestamp) > targetTimeWindow {
            sample.removeFirst()
        }
        while rawSample.count > 1, let oldest = rawSample.first, newest.timestamp.timeIntervalSince(oldest.timestamp) > targetTimeWindow {
            rawSample.removeFirst()
        }

        let n = sample.count

        guard n > 1 else {
            let result: MovingState = (newest.speed < meanSpeedThreshold + sdSpeedThreshold) ? .stationary : .moving
            return MovingStateDetails(
                result, n: 1, timestamp: newest.timestamp,
                meanAccuracy: newest.horizontalAccuracy,
                meanSpeed: newest.speed
            )
        }

        let meanAccuracy = sample.map { $0.horizontalAccuracy }.reduce(0, +) / Double(sample.count)

        guard meanAccuracy <= accuracyThreshold else {
            return MovingStateDetails(.uncertain, n: n, timestamp: newest.timestamp, meanAccuracy: meanAccuracy)
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
        var result: MovingState = (weightedMeanSpeed < meanSpeedThreshold && weightedStdDev < sdSpeedThreshold) ? .stationary : .moving

        // Raw speed=-1 override: if Kalman says moving but raw speed=-1 rate
        // is high, the device is likely genuinely stationary — iOS is honestly
        // reporting "I don't know" which only happens when not moving
        if result == .moving, !rawSample.isEmpty {
            let invalidCount = rawSample.filter { $0.invalidVelocity }.count
            let invalidRate = Double(invalidCount) / Double(rawSample.count)
            if invalidRate >= rawSpeedInvalidThreshold {
                result = .stationary
                Log.info("StationaryStateDetector overrode .moving → .stationary (raw invalidVelocity rate: \(Int(invalidRate * 100))%, \(rawSample.count) raws)", subsystem: .misc)
            }
        }

        return MovingStateDetails(
            result, n: n,
            timestamp: newest.timestamp,
            meanAccuracy: meanAccuracy,
            meanSpeed: weightedMeanSpeed,
            sdSpeed: weightedStdDev
        )
    }

}
