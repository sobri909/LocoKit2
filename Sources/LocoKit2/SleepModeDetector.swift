//
//  SleepModeDetector.swift
//
//
//  Created by Matt Greenfield on 6/3/24.
//

import Foundation
import CoreLocation

actor SleepModeDetector {

    // MARK: - Config

    public static let sleepModeDelay: TimeInterval = 120.0
    private let minGeofenceRadius: CLLocationDistance = 20.0
    private let maxGeofenceRadius: CLLocationDistance = 100.0

    // MARK: - Public

    private(set) var state = SleepDetectorState()

    func add(location: CLLocation) {
        if state.isFrozen {
            updateTheFrozenState(with: location)
        } else {
            updateTheUnfrozenState(with: location)
        }
    }

    // MARK: - Private

    private var sample: [CLLocation] = []
    private var updateTask: Task<(), Never>?

    private func freeze() {
        state.isFrozen = true
    }

    private func unfreeze() {
        state.lastGeofenceEnterTime = nil
        state.shouldBeSleeping = false
        state.isFrozen = false
    }

    private func updateTheFrozenState(with location: CLLocation) {
        guard state.isFrozen else { return }

        state.isLocationWithinGeofence = isWithinGeofence(location)

        if !state.isLocationWithinGeofence {
            unfreeze()
        }
    }

    private func updateTheUnfrozenState(with location: CLLocation? = nil) {
        if state.isFrozen { return }

        // add the new location
        if let location {
            sample.append(location)
            sample.sort { $0.timestamp < $1.timestamp }
        }

        guard let newest = sample.last else { return }

        // age out samples older than sleepModeDelay
        while sample.count > 1, let oldest = sample.first, oldest.timestamp.age > Self.sleepModeDelay {
            sample.removeFirst()
        }

        // location updates might stall, but need to keep state current
        defer {
            updateTask?.cancel()
            updateTask = Task {
                try? await Task.sleep(for: .seconds(6))
                if !Task.isCancelled {
                    updateTheUnfrozenState()
                }
            }
        }

        // debug stats
        state.n = sample.count
        if let oldest = sample.first {
            state.sampleDuration = newest.timestamp.timeIntervalSince(oldest.timestamp)
        }

        // keep the fence current
        updateGeofence()

        state.isLocationWithinGeofence = isWithinGeofence(newest)

        // make sure lastGeofenceEnterTime is correct
        if state.isLocationWithinGeofence {
            if state.lastGeofenceEnterTime == nil {
                state.lastGeofenceEnterTime = newest.timestamp
            }
        } else {
            state.lastGeofenceEnterTime = nil
        }

        state.shouldBeSleeping = state.durationWithinGeofence >= Self.sleepModeDelay

        // ensure correct frozen state
        if state.shouldBeSleeping {
            freeze()
        }
    }

    private func updateGeofence() {
        if state.isFrozen { return }

        guard let center = sample.weightedCenter() else { return }

        state.geofenceCenter = center

        // Calculate the average horizontal accuracy from the sample buffer
        let averageAccuracy = sample.reduce(0.0) { $0 + $1.horizontalAccuracy } / Double(sample.count)

        // early exit and simple maths if n = 1
        guard sample.count > 1 else {
            state.geofenceRadius = min(max(pow(averageAccuracy, 2), minGeofenceRadius), maxGeofenceRadius)
            return
        }

        // mean distance from the weighted center
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let totalDistance = sample.reduce(0.0) { $0 + $1.distance(from: centerLocation) }
        let meanDistance = totalDistance / Double(sample.count)

        // Clamp the geofence radius within the specified range
        state.geofenceRadius = min(max(averageAccuracy, minGeofenceRadius), maxGeofenceRadius)
//        state.geofenceRadius = min(max(averageAccuracy + meanDistance, minGeofenceRadius), maxGeofenceRadius)
    }

    private func isWithinGeofence(_ location: CLLocation) -> Bool {
        guard let center = state.geofenceCenter else { return false }
        let distance = location.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
        return distance <= state.geofenceRadius
    }

}

public struct SleepDetectorState {
    public var isFrozen: Bool = false
    public var geofenceCenter: CLLocationCoordinate2D? = nil
    public var geofenceRadius: CLLocationDistance = 50.0
    public var lastGeofenceEnterTime: Date? = nil
    public var isLocationWithinGeofence: Bool = false
    public var shouldBeSleeping: Bool = false

    // debug bits
    public var sampleDuration: TimeInterval = 0
    public var n: Int = 0

    public var durationWithinGeofence: TimeInterval {
        if !isLocationWithinGeofence { return 0 }
        return lastGeofenceEnterTime?.age ?? 0
    }
}
