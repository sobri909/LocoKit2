//
//  LocomotionSample+Array.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 18/12/2024.
//

import Foundation
import CoreLocation

public extension Array where Element == LocomotionSample {

    func dateRange() -> DateInterval? {
        let dates = map { $0.date }
        guard let start = dates.min(), let end = dates.max() else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    func usableLocations() -> [CLLocation] {
        return filter { $0.hasUsableCoordinate }.compactMap { $0.location }
    }

    func haveAnyUsableCoordinates() -> Bool {
        return contains { $0.hasUsableCoordinate }
    }

    func weightedCenter() -> CLLocationCoordinate2D? {
        let usableSamples = self.filter { $0.hasUsableCoordinate }

        if usableSamples.isEmpty { return nil }
        if usableSamples.count == 1, let location = usableSamples.first?.location {
            return location.coordinate
        }

        var sumX: Double = 0
        var sumY: Double = 0
        var sumZ: Double = 0
        var totalWeight: Double = 0

        for sample in usableSamples {
            guard let location = sample.location else { continue }

            let latitude = location.coordinate.latitude.radians
            let longitude = location.coordinate.longitude.radians

            // Clamp accuracy to avoid division by zero or overly large weights
            let clampedAccuracy = Swift.max(location.horizontalAccuracy, 1.0)
            let baseWeight = 1 / (clampedAccuracy * clampedAccuracy)

            // multiply weight for stationary samples
            let weight = sample.activityType == .stationary ? baseWeight * 10 : baseWeight

            let cosLatitude = cos(latitude)
            let sinLatitude = sin(latitude)
            let cosLongitude = cos(longitude)
            let sinLongitude = sin(longitude)

            sumX += cosLatitude * cosLongitude * weight
            sumY += cosLatitude * sinLongitude * weight
            sumZ += sinLatitude * weight
            totalWeight += weight
        }

        // Compute average vector
        let averageX = sumX / totalWeight
        let averageY = sumY / totalWeight
        let averageZ = sumZ / totalWeight

        // Convert back to lat/long
        let averageLatitude = atan2(averageZ, sqrt(averageX * averageX + averageY * averageY)).degrees
        let averageLongitude = atan2(averageY, averageX).degrees

        return CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)
    }

    func radius(from center: CLLocation) -> Radius {
        return usableLocations().radius(from: center)
    }

    func weightedRadius(from center: CLLocation) -> Radius {
        let usableSamples = self.filter { $0.hasUsableCoordinate }

        let weightedDistances = usableSamples.compactMap { sample -> (distance: Double, weight: Double)? in
            guard let location = sample.location else { return nil }

            // Clamp accuracy to a small positive value if zero or negative
            let clampedAccuracy = Swift.max(location.horizontalAccuracy, 1.0)

            let baseWeight = 1 / (clampedAccuracy * clampedAccuracy)
            let weight = sample.activityType == .stationary ? baseWeight * 10 : baseWeight

            let distance = location.distance(from: center)
            return (distance, weight)
        }

        // Guard against empty results
        if weightedDistances.isEmpty { return .zero }

        // Calculate weighted mean
        let totalWeight = weightedDistances.reduce(0.0) { $0 + $1.weight }
        let weightedMean = weightedDistances.reduce(0.0) { $0 + ($1.distance * $1.weight) } / totalWeight

        // Calculate weighted standard deviation
        let weightedSquaredDiffs = weightedDistances.map {
            pow($0.distance - weightedMean, 2) * $0.weight
        }
        let weightedVariance = weightedSquaredDiffs.reduce(0.0, +) / totalWeight
        let weightedSD = sqrt(weightedVariance)

        return Radius(mean: weightedMean, sd: weightedSD)
    }

}
