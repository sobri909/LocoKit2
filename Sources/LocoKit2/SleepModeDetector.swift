//
//  SleepModeDetector.swift
//
//
//  Created by Matt Greenfield on 6/3/24.
//

import Foundation
import CoreLocation

actor SleepModeDetector {

    var geofenceRadius: CLLocationDistance = 50.0
    private let sleepModeDelay: TimeInterval = 120.0 // 2 minutes
    private let minSampleCount: Int = 5 // Minimum number of samples required for geofence calculation
    private let minGeofenceRadius: CLLocationDistance = 10.0 // Minimum geofence radius in meters
    private let maxGeofenceRadius: CLLocationDistance = 100.0 // Maximum geofence radius in meters
    private let horizontalAccuracyMultiplier: Double = 2.0 // Multiplier for horizontal accuracy

    private var sampleBuffer: [CLLocation] = []
    private(set) var geofenceCenter: CLLocationCoordinate2D?
    private(set) var lastGeofenceEnterTime: Date?

    private(set) var isLocationWithinGeofence: Bool = false

    var durationWithinGeofence: TimeInterval {
        guard let lastEnterTime = lastGeofenceEnterTime else {
            return 0
        }
        return lastEnterTime.age
    }

    func add(location: CLLocation) {
        sampleBuffer.append(location)

        // Remove samples older than sleepModeDelay
        while let oldest = sampleBuffer.first, location.timestamp.timeIntervalSince(oldest.timestamp) > sleepModeDelay {
            sampleBuffer.removeFirst()
        }

        // Update geofence if enough samples are available
        if sampleBuffer.count >= minSampleCount {
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

    private func updateGeofence() {
        // Calculate the average horizontal accuracy from the sample buffer
        let averageAccuracy = sampleBuffer.reduce(0.0) { $0 + $1.horizontalAccuracy } / Double(sampleBuffer.count)

        print("averageAccuracy: \(averageAccuracy)")
        // Calculate the geofence radius based on the average horizontal accuracy
        geofenceRadius = min(max(averageAccuracy * horizontalAccuracyMultiplier, minGeofenceRadius), maxGeofenceRadius)

        // Calculate the center of the geofence based on the sample buffer
        if let center = sampleBuffer.weightedCenter() {
            geofenceCenter = center
        }
    }

    private func isWithinGeofence(_ location: CLLocation, center: CLLocationCoordinate2D) -> Bool {
        // Calculate the distance between the location and the geofence center
        let distance = location.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))

        // Check if the distance is within the geofence radius
        return distance <= geofenceRadius
    }

}
