//
//  DriftProfile+Inflation.swift
//  Arc Timeline
//
//  Created by Claude on 2026-04-18
//

import Foundation
import CoreLocation

extension DriftProfile {

    // MARK: - Real-time Inflation (Trust Factor Layer 2)

    /// Returns an inflated copy of the raw location based on this profile's drift signature
    /// relative to the given centroid, or nil if no inflation applies (sector has no history).
    ///
    /// Stands in front of the Kalman filter: inflated `horizontalAccuracy` and `speedAccuracy`
    /// tell the Kalman to discount the measurement in learned drift directions. All other
    /// CLLocation fields are copied through unchanged.
    ///
    /// The `invalidVelocity` pass-through preserves iOS's "don't know" signals (speed=-1,
    /// speedAccuracy>=20, etc). Overwriting them would waste a stronger anchor the Kalman
    /// already handles well (zero velocity with 0.01 confidence).
    public func inflate(_ location: CLLocation, relativeTo centroid: CLLocation) -> CLLocation? {
        let bearing = centroid.coordinate.bearing(to: location.coordinate)
        let sector = Int(bearing / 45.0) % 8

        let count = directionCounts[sector]
        guard count > 0 else { return nil }  // no drift history in this direction

        // confidence ramps with count — 5+ samples = full confidence in this sector's magnitude
        let confidence = min(1.0, Double(count) / 5.0)
        let sectorMagnitude = directionMagnitudes[sector]
        let effectiveInflation = sectorMagnitude * confidence

        // scale hAcc and speedAccuracy proportionally to effective inflation
        let inflatedHAcc = max(location.horizontalAccuracy, effectiveInflation)
        // leave invalidVelocity raws untouched — iOS's "don't know" already gives Kalman a zero-velocity anchor
        // otherwise stay below the 20.0 invalidVelocity sentinel — let Kalman's quadratic variance do the work
        let inflatedSpdAcc: Double
        if location.invalidVelocity {
            inflatedSpdAcc = location.speedAccuracy
        } else {
            inflatedSpdAcc = min(19.0, max(location.speedAccuracy, effectiveInflation / 5))
        }

        let distance = location.distance(from: centroid)
        Log.info(
            "DriftInflation: \(Int(distance))m at \(Int(bearing))° (sector \(sector), " +
            "\(count) samples × \(Int(sectorMagnitude))m × conf \(String(format: "%.2f", confidence)) = \(Int(effectiveInflation))m effective), " +
            "hAcc \(Int(location.horizontalAccuracy))→\(Int(inflatedHAcc))m, " +
            "spdAcc \(String(format: "%.1f", location.speedAccuracy))→\(String(format: "%.1f", inflatedSpdAcc))",
            subsystem: .locomotion
        )

        return CLLocation(
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: inflatedHAcc,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            courseAccuracy: location.courseAccuracy,
            speed: location.speed,
            speedAccuracy: inflatedSpdAcc,
            timestamp: location.timestamp
        )
    }

}
