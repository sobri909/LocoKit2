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

    private let sleepModeDelay: TimeInterval = 120.0 
    private let minGeofenceRadius: CLLocationDistance = 10.0
    private let maxGeofenceRadius: CLLocationDistance = 100.0

    // MARK: - Public

    private(set) var state = SleepDetectorState()

    func add(location: CLLocation) {
        if state.isFrozen {
            // if frozen, don't update the geofence, only check if the location is within the geofence
            if let center = state.geofenceCenter {
                state.isLocationWithinGeofence = isWithinGeofence(location, center: center)
            }
            return
        }

        sample.append(location)
        sample.sort { $0.timestamp < $1.timestamp }

        updateTheState()
    }

    func freeze() {
        state.isFrozen = true
    }

    func unfreeze() {
        state.isFrozen = false
        state.lastGeofenceEnterTime = nil
        updateTheState()
    }

    // MARK: - Private

    private var sample: [CLLocation] = []
    private var updateTask: Task<(), Never>?

    private func updateTheState() {
        if state.isFrozen { return }

        guard let newest = sample.last else { return }

        // age out samples older than sleepModeDelay
        while sample.count > 1, let oldest = sample.first, oldest.timestamp.age > sleepModeDelay {
            sample.removeFirst()
        }

        // debug stats
        state.n = sample.count
        if let oldest = sample.first {
            state.sampleDuration = newest.timestamp.timeIntervalSince(oldest.timestamp)
        }

        // Update geofence if enough samples are available
        if !sample.isEmpty {
            updateGeofence()
        }

        // Check if the location is within the geofence
        if let center = state.geofenceCenter {
            state.isLocationWithinGeofence = isWithinGeofence(newest, center: center)

            if state.isLocationWithinGeofence {
                // Update the last geofence enter time if not already set
                if state.lastGeofenceEnterTime == nil {
                    state.lastGeofenceEnterTime = newest.timestamp
                }
            } else {
                // Reset the last geofence enter time if the location is outside the geofence
                state.lastGeofenceEnterTime = nil
            }
        } else {
            state.isLocationWithinGeofence = false
            state.lastGeofenceEnterTime = nil
        }

        // location updates might stall, but need to keep state current
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                updateTheState()
            }
        }
    }

    private func updateGeofence() {
        guard let center = sample.weightedCenter() else { return }

        state.geofenceCenter = center

        // Calculate the average horizontal accuracy from the sample buffer
        let averageAccuracy = sample.reduce(0.0) { $0 + $1.horizontalAccuracy } / Double(sample.count)

        // early exit and simple maths if n = 1
        if sample.count == 1 {
            state.geofenceRadius = min(max(averageAccuracy * 2, minGeofenceRadius), maxGeofenceRadius)
            return
        }

        // Create a single CLLocation instance for the center
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        // Calculate the mean distance from the weighted center
        let totalDistance = sample.reduce(0.0) { $0 + $1.distance(from: centerLocation) }
        let meanDistance = totalDistance / Double(sample.count)

        // Clamp the geofence radius within the specified range
        state.geofenceRadius = min(max(averageAccuracy + meanDistance, minGeofenceRadius), maxGeofenceRadius)
    }

    private func isWithinGeofence(_ location: CLLocation, center: CLLocationCoordinate2D) -> Bool {
        // Calculate the distance between the location and the geofence center
        let distance = location.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))

        // Check if the distance is within the geofence radius
        return distance <= state.geofenceRadius
    }

}

public struct SleepDetectorState {
    public var isFrozen: Bool = false
    public var geofenceCenter: CLLocationCoordinate2D? = nil
    public var lastGeofenceEnterTime: Date? = nil
    public var isLocationWithinGeofence: Bool = false
    public var geofenceRadius: CLLocationDistance = 50.0
    public var sampleDuration: TimeInterval = 0
    public var n: Int = 0

    public var durationWithinGeofence: TimeInterval {
        lastGeofenceEnterTime?.age ?? 0
    }
}
