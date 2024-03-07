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

    private let sleepModeDelay: TimeInterval = 120.0 // 2 minutes
    private let minGeofenceRadius: CLLocationDistance = 10.0 // Minimum geofence radius in meters
    private let maxGeofenceRadius: CLLocationDistance = 100.0 // Maximum geofence radius in meters

    // MARK: - Output

    private(set) var geofenceCenter: CLLocationCoordinate2D?
    private(set) var lastGeofenceEnterTime: Date?
    private(set) var isLocationWithinGeofence: Bool = false
    private(set) var geofenceRadius: CLLocationDistance = 50.0

    var durationWithinGeofence: TimeInterval { lastGeofenceEnterTime?.age ?? 0 }

    // MARK: - Input

    func add(location: CLLocation) {
        sampleBuffer.append(location)

        // Remove samples older than sleepModeDelay
        while sampleBuffer.count > 1, let oldest = sampleBuffer.first, location.timestamp.timeIntervalSince(oldest.timestamp) > sleepModeDelay {
            sampleBuffer.removeFirst()
        }

        // Update geofence if enough samples are available
        if !sampleBuffer.isEmpty {
            updateGeofence()
        }

        // Check if the location is within the geofence
        if let center = geofenceCenter {
            isLocationWithinGeofence = isWithinGeofence(location, center: center)

            if isLocationWithinGeofence {
                // Update the last geofence enter time if not already set
                if lastGeofenceEnterTime == nil {
                    lastGeofenceEnterTime = location.timestamp
                }
            } else {
                // Reset the last geofence enter time if the location is outside the geofence
                lastGeofenceEnterTime = nil
            }
        } else {
            isLocationWithinGeofence = false
            lastGeofenceEnterTime = nil
        }
    }

    // MARK: - Private

    private var sampleBuffer: [CLLocation] = []

    private func updateGeofence() {
        guard let center = sampleBuffer.weightedCenter() else { return }

        geofenceCenter = center

        // Calculate the average horizontal accuracy from the sample buffer
        let averageAccuracy = sampleBuffer.reduce(0.0) { $0 + $1.horizontalAccuracy } / Double(sampleBuffer.count)

        // early exit and simple maths if n = 1
        if sampleBuffer.count == 1 {
            geofenceRadius = min(max(averageAccuracy * 2, minGeofenceRadius), maxGeofenceRadius)
            return
        }

        // Create a single CLLocation instance for the center
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        // Calculate the mean distance from the weighted center
        let totalDistance = sampleBuffer.reduce(0.0) { $0 + $1.distance(from: centerLocation) }
        let meanDistance = totalDistance / Double(sampleBuffer.count)

        // Clamp the geofence radius within the specified range
        geofenceRadius = min(max(averageAccuracy + meanDistance, minGeofenceRadius), maxGeofenceRadius)
    }

    private func isWithinGeofence(_ location: CLLocation, center: CLLocationCoordinate2D) -> Bool {
        // Calculate the distance between the location and the geofence center
        let distance = location.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))

        // Check if the distance is within the geofence radius
        return distance <= geofenceRadius
    }

}
