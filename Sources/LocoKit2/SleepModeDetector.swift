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
            // If frozen, don't update the geofence and only check if the location is within the geofence
            if let center = state.geofenceCenter {
                state.isLocationWithinGeofence = isWithinGeofence(location, center: center)
            }
            return
        }

        sampleBuffer.append(location)

        // Remove samples older than sleepModeDelay
        while sampleBuffer.count > 1, let oldest = sampleBuffer.first, location.timestamp.timeIntervalSince(oldest.timestamp) > sleepModeDelay {
            sampleBuffer.removeFirst()
        }

        // debug stats
        state.n = sampleBuffer.count
        if let oldest = sampleBuffer.first {
            state.sampleDuration = location.timestamp.timeIntervalSince(oldest.timestamp)
        }

        // Update geofence if enough samples are available
        if !sampleBuffer.isEmpty {
            updateGeofence()
        }

        // Check if the location is within the geofence
        if let center = state.geofenceCenter {
            state.isLocationWithinGeofence = isWithinGeofence(location, center: center)

            if state.isLocationWithinGeofence {
                // Update the last geofence enter time if not already set
                if state.lastGeofenceEnterTime == nil {
                    state.lastGeofenceEnterTime = location.timestamp
                }
            } else {
                // Reset the last geofence enter time if the location is outside the geofence
                state.lastGeofenceEnterTime = nil
            }
        } else {
            state.isLocationWithinGeofence = false
            state.lastGeofenceEnterTime = nil
        }
    }

    func freeze() {
        state.isFrozen = true
    }

    func unfreeze() {
        state.isFrozen = false
    }

    // MARK: - Private

    private var sampleBuffer: [CLLocation] = []

    private func updateGeofence() {
        guard let center = sampleBuffer.weightedCenter() else { return }

        state.geofenceCenter = center

        // Calculate the average horizontal accuracy from the sample buffer
        let averageAccuracy = sampleBuffer.reduce(0.0) { $0 + $1.horizontalAccuracy } / Double(sampleBuffer.count)

        // early exit and simple maths if n = 1
        if sampleBuffer.count == 1 {
            state.geofenceRadius = min(max(averageAccuracy * 2, minGeofenceRadius), maxGeofenceRadius)
            return
        }

        // Create a single CLLocation instance for the center
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        // Calculate the mean distance from the weighted center
        let totalDistance = sampleBuffer.reduce(0.0) { $0 + $1.distance(from: centerLocation) }
        let meanDistance = totalDistance / Double(sampleBuffer.count)

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
