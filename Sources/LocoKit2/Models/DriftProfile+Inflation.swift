//
//  DriftProfile+Inflation.swift
//  Arc Timeline
//
//  Created by Claude on 2026-04-18
//

import Foundation
import CoreLocation

// MARK: - DriftInflationResult

/// Diagnostic result of a drift inflation attempt. Always populated when a profile is consulted,
/// regardless of whether inflation was actually applied. Use `didInflate` to determine whether
/// `inflatedLocation` should be substituted for the raw; when false, `inflatedLocation == location`
/// and the profile had no drift history in the relevant sector.
public struct DriftInflationResult: Sendable {

    public let inflatedLocation: CLLocation
    public let bearing: Double            // 0-360° from centroid
    public let sector: Int                 // 0-7 (45° each)
    public let distance: Double            // metres from centroid
    public let count: Int                  // excursion samples in this sector
    public let sectorMagnitude: Double     // mean drift distance in this sector (metres)
    public let confidence: Double          // count-based confidence, 0-1
    public let effectiveInflation: Double  // sectorMagnitude * confidence
    public let rawHAcc: Double
    public let rawSpdAcc: Double
    public let inflatedHAcc: Double
    public let inflatedSpdAcc: Double

    /// True when inflation was actually applied (sector had drift history). When false,
    /// the profile was consulted but no modification was made.
    public var didInflate: Bool { count > 0 }

    public var logDescription: String {
        "DriftInflation: \(Int(distance))m at \(Int(bearing))° (sector \(sector), " +
        "\(count) samples × \(Int(sectorMagnitude))m × conf \(String(format: "%.2f", confidence)) = \(Int(effectiveInflation))m effective), " +
        "hAcc \(Int(rawHAcc))→\(Int(inflatedHAcc))m, " +
        "spdAcc \(String(format: "%.1f", rawSpdAcc))→\(String(format: "%.1f", inflatedSpdAcc))"
    }
}

// MARK: - DriftProfile inflation

extension DriftProfile {

    // MARK: - Real-time Inflation (Trust Factor Layer 2)

    /// Computes drift inflation for the given location relative to the given centroid.
    ///
    /// Always returns a result with full inspection details. When `count > 0` for the sector,
    /// `inflatedLocation` has inflated `horizontalAccuracy` and `speedAccuracy`; otherwise it
    /// equals the input location. Callers should check `didInflate` before substituting.
    ///
    /// The `invalidVelocity` pass-through preserves iOS's "don't know" signals (speed=-1,
    /// speedAccuracy>=20, etc). Overwriting them would waste a stronger anchor the Kalman
    /// already handles well (zero velocity with 0.01 confidence).
    public func inflate(_ location: CLLocation, relativeTo centroid: CLLocation) -> DriftInflationResult {
        let bearing = centroid.coordinate.bearing(to: location.coordinate)
        let sector = Int(bearing / 45.0) % 8
        let distance = location.distance(from: centroid)

        let count = directionCounts[sector]
        let sectorMagnitude = directionMagnitudes[sector]
        let confidence = min(1.0, Double(count) / 5.0)
        let effectiveInflation = sectorMagnitude * confidence

        // no history in this sector — return result with inflatedLocation == location
        guard count > 0 else {
            return DriftInflationResult(
                inflatedLocation: location,
                bearing: bearing,
                sector: sector,
                distance: distance,
                count: count,
                sectorMagnitude: sectorMagnitude,
                confidence: confidence,
                effectiveInflation: effectiveInflation,
                rawHAcc: location.horizontalAccuracy,
                rawSpdAcc: location.speedAccuracy,
                inflatedHAcc: location.horizontalAccuracy,
                inflatedSpdAcc: location.speedAccuracy
            )
        }

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

        let inflatedLocation = CLLocation(
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

        return DriftInflationResult(
            inflatedLocation: inflatedLocation,
            bearing: bearing,
            sector: sector,
            distance: distance,
            count: count,
            sectorMagnitude: sectorMagnitude,
            confidence: confidence,
            effectiveInflation: effectiveInflation,
            rawHAcc: location.horizontalAccuracy,
            rawSpdAcc: location.speedAccuracy,
            inflatedHAcc: inflatedHAcc,
            inflatedSpdAcc: inflatedSpdAcc
        )
    }

}
