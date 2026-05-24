//
//  UndergroundDetector.swift
//  LocoKit2
//
//  Created by Claude on 2026-05-24
//
//  BIG-150: Detects GPS-fallback-to-cell-tower-triangulation regimes (most
//  commonly underground train trips) and reshapes raw CLLocations so the
//  Kalman filter can follow the actual movement instead of being locked
//  to the origin by the zero-velocity-with-0.01-confidence anchor that
//  invalidVelocity raws trigger.
//
//  v0.0.1 parameters calibrated via python harness against Trip 1 Bangkok
//  MRT data (docs/diagnostics/BIG-150/python_harness/). Sustained predicate
//  (consecutive invalidVelocity + rolling-avg high hAcc + sustained duration)
//  gates the reshape. When in regime, Layer 2 (DriftProfile) inflation is
//  skipped for that raw — see LocomotionManager.add(location:) coexistence.
//

import Foundation
import CoreLocation

public actor UndergroundDetector {

    // MARK: - Config (v0.0.1, calibrated via python harness)

    /// Number of consecutive invalidVelocity raws required for predicate match
    private let minConsecutiveInvalidVelocity: Int = 3

    /// Rolling-window hAcc average threshold (meters) — distinguishes GPS-fallback
    /// regime from drift germinations (which have low hAcc, ~15m) and normal
    /// recording. iOS reports km-scale hAcc when falling back to cell-tower
    /// triangulation only; 500m is a safe-margin threshold below that.
    private let hAccRollingAvgThreshold: CLLocationAccuracy = 500.0

    /// Sustained duration before in_regime engages (seconds) — warmup period
    /// distinguishes genuine sustained regime from transient invalidVelocity
    /// bursts (drift germinations are 14-126s but with low hAcc, so combined
    /// with hAcc threshold this 30s warmup is conservative).
    private let minSustainedDuration: TimeInterval = 30.0

    /// Time-bounded rolling window for hAcc averaging (seconds)
    private let rollingWindowDuration: TimeInterval = 60.0

    /// Reshape: clamp incoming hAcc to this value when in regime. Aggressive
    /// because we want Kalman to actually follow the raw stream, not just
    /// drift toward it.
    private let reshapeClampHAcc: CLLocationAccuracy = 20.0

    /// Reshape: override speedAccuracy to this value (MUST be < 20 sentinel
    /// to bypass invalidVelocity check). Removes the zero-velocity-with-0.01-
    /// confidence anchor that's the structural blocker for tracking real
    /// underground movement.
    private let reshapeRelaxedSpeedAcc: CLLocationSpeedAccuracy = 19.0

    // MARK: - State

    private var consecutiveInvalidVelocityCount: Int = 0
    private var regimeEntryTime: Date?
    private var rollingHAccWindow: [(timestamp: Date, hAcc: CLLocationAccuracy)] = []
    private var inRegime: Bool = false

    public init() {}

    // MARK: - Public API

    public func evaluate(rawLocation: CLLocation) -> EvaluationResult {
        let now = rawLocation.timestamp
        let invalidVel = rawLocation.invalidVelocity

        // 1. Update consecutive invalidVelocity counter
        if invalidVel {
            consecutiveInvalidVelocityCount += 1
        } else {
            consecutiveInvalidVelocityCount = 0
        }

        // 2. Update rolling hAcc window (time-bounded)
        rollingHAccWindow.append((now, rawLocation.horizontalAccuracy))
        while let oldest = rollingHAccWindow.first,
              now.timeIntervalSince(oldest.timestamp) > rollingWindowDuration {
            rollingHAccWindow.removeFirst()
        }

        // 3. Evaluate predicate
        let rollingHAccAvg = rollingHAccWindow.isEmpty ? nil :
            rollingHAccWindow.map(\.hAcc).reduce(0, +) / Double(rollingHAccWindow.count)
        let predicateMatched =
            consecutiveInvalidVelocityCount >= minConsecutiveInvalidVelocity &&
            (rollingHAccAvg ?? 0) > hAccRollingAvgThreshold

        // 4. State machine — entry needs sustained duration (warmup), exit on any predicate-break
        let wasInRegime = inRegime
        var sustainedDuration: TimeInterval? = nil
        if predicateMatched {
            if regimeEntryTime == nil {
                regimeEntryTime = now
            }
            sustainedDuration = now.timeIntervalSince(regimeEntryTime!)
            inRegime = (sustainedDuration ?? 0) >= minSustainedDuration
        } else {
            regimeEntryTime = nil
            inRegime = false
        }

        // 5. Log state transitions
        if !wasInRegime && inRegime {
            Log.info("UndergroundDetector: REGIME ENTRY (consecutive=\(consecutiveInvalidVelocityCount), rollingHAccAvg=\(formatM(rollingHAccAvg)), sustained=\(formatS(sustainedDuration)))", subsystem: .locomotion)
        } else if wasInRegime && !inRegime {
            Log.info("UndergroundDetector: REGIME EXIT (predicate broken)", subsystem: .locomotion)
        }

        // 6. Reshape if in regime
        let reshapedLocation = inRegime ? reshape(rawLocation) : rawLocation

        // 7. Per-raw diagnostic logging
        if inRegime {
            Log.info("UndergroundDetector: reshape raw hAcc=\(formatM(rawLocation.horizontalAccuracy))→\(formatM(reshapeClampHAcc)), spdAcc=\(String(format: "%.2f", rawLocation.speedAccuracy))→\(String(format: "%.0f", reshapeRelaxedSpeedAcc))", subsystem: .locomotion)
        } else if predicateMatched {
            // warming phase — predicate matched but sustained-duration not yet reached
            Log.info("UndergroundDetector: predicate matched, warming (sustained=\(formatS(sustainedDuration))/\(formatS(minSustainedDuration)))", subsystem: .locomotion)
        }

        return EvaluationResult(
            inRegime: inRegime,
            wasInRegimeBefore: wasInRegime,
            reshapedLocation: reshapedLocation,
            rollingHAccAvg: rollingHAccAvg,
            consecutiveInvalidVelocityCount: consecutiveInvalidVelocityCount,
            sustainedDuration: sustainedDuration,
            predicateMatched: predicateMatched
        )
    }

    // MARK: - Private

    private func reshape(_ raw: CLLocation) -> CLLocation {
        // Clamp hAcc + relax invalidVelocity by setting speedAccuracy below
        // sentinel (19 < 20) and clamping negative speed/course to 0 so the
        // Kalman doesn't apply the zero-velocity-with-0.01-confidence anchor.
        let clampedHAcc = min(raw.horizontalAccuracy, reshapeClampHAcc)
        let safeSpeed = raw.speed < 0 ? 0.0 : raw.speed
        let safeCourse = raw.course < 0 ? 0.0 : raw.course
        let safeCourseAcc = raw.courseAccuracy < 0 ? reshapeRelaxedSpeedAcc : raw.courseAccuracy

        return CLLocation(
            coordinate: raw.coordinate,
            altitude: raw.altitude,
            horizontalAccuracy: clampedHAcc,
            verticalAccuracy: raw.verticalAccuracy,
            course: safeCourse,
            courseAccuracy: safeCourseAcc,
            speed: safeSpeed,
            speedAccuracy: reshapeRelaxedSpeedAcc,
            timestamp: raw.timestamp
        )
    }

    private func formatM(_ value: Double?) -> String {
        guard let value else { return "?" }
        return String(format: "%.0f", value) + "m"
    }

    private func formatS(_ value: TimeInterval?) -> String {
        guard let value else { return "?" }
        return String(format: "%.1f", value) + "s"
    }

    // MARK: - Result struct

    public struct EvaluationResult: Sendable {
        public let inRegime: Bool
        public let wasInRegimeBefore: Bool
        public let reshapedLocation: CLLocation
        public let rollingHAccAvg: CLLocationAccuracy?
        public let consecutiveInvalidVelocityCount: Int
        public let sustainedDuration: TimeInterval?
        public let predicateMatched: Bool

        public var didEnterRegime: Bool { !wasInRegimeBefore && inRegime }
        public var didExitRegime: Bool { wasInRegimeBefore && !inRegime }
    }
}
