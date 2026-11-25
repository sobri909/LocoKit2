//
//  RawFixJumpCheck.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-25
//

import Foundation
import CoreLocation

/// BIG-1032: an instrument, not a filter. Names a pair of consecutive accepted raw fixes that no
/// vehicle could have connected in the time between them while both claim good accuracy. The intake
/// logs one line per such pair and handles the fix exactly as before.
///
/// Why: BIG-1029's drive was stored with runs of positions tens of kilometres off the route, every
/// one with hAcc under 25 m, and the bundle could not say what the phone had delivered. A per-pair
/// check gives exactly one line at each switch (into a far run, and back out): consecutive fixes
/// inside a run are near each other, so no line per fix inside it.
///
/// The thresholds start from the ticket's candidates and are meant to fire almost never: an airliner's
/// ground speed in a jet stream can pass 1,000 km/h (the records are near 1,290 km/h), so the speed
/// bound sits at 1,500 km/h, which still catches BIG-1029's switches (thousands of m/s); the distance
/// floor keeps two fixes milliseconds apart from tripping on their own jitter; a negative accuracy is
/// Core Location's "invalid" and never trips. The intake caps the line to one a minute, carrying the
/// count of pairs it did not describe (an interleaved stream at 1 Hz fires on most fixes). Nothing
/// here reads or writes state, so it is safe from any actor.
enum RawFixJumpCheck {

    /// Implied speed above which a pair is implausible: 1,500 km/h.
    static let maxPlausibleSpeed: CLLocationSpeed = 1_500_000.0 / 3600.0

    /// The intake writes at most one line per this interval; pairs inside it are counted on the next line.
    static let minimumLogInterval: TimeInterval = 60

    /// Both fixes must claim horizontal accuracy under this to count as "good accuracy".
    static let goodAccuracy: CLLocationAccuracy = 100

    /// The pair must be at least this far apart to be considered at all.
    static let minimumDistance: CLLocationDistance = 500

    struct Report: Sendable {
        let distance: CLLocationDistance
        let interval: TimeInterval
        var impliedSpeed: CLLocationSpeed { distance / interval }
    }

    /// nil when the pair is plausible, out of order, too close together, or either fix's accuracy is
    /// not good.
    static func report(previous: CLLocation, current: CLLocation) -> Report? {
        guard previous.horizontalAccuracy >= 0, current.horizontalAccuracy >= 0 else { return nil }
        guard previous.horizontalAccuracy < goodAccuracy, current.horizontalAccuracy < goodAccuracy else { return nil }
        let interval = current.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0 else { return nil }
        let distance = current.distance(from: previous)
        guard distance >= minimumDistance else { return nil }
        guard distance / interval > maxPlausibleSpeed else { return nil }
        return Report(distance: distance, interval: interval)
    }

    /// The log line for a report. Carries no coordinates: each fix's timestamp, claimed horizontal
    /// accuracy, reported speed and course, and its age at delivery (delivered − timestamp) where the
    /// delivery time is known; then the distance and the implied speed.
    static func logLine(_ report: Report, previous: CLLocation, current: CLLocation,
                               previousDeliveredAt: Date?, currentDeliveredAt: Date) -> String {
        let distance = report.distance >= 1000
            ? String(format: "%.1f km", report.distance / 1000)
            : String(format: "%.0f m", report.distance)
        let speed = String(format: "%.0f m/s (%.0f km/h)", report.impliedSpeed, report.impliedSpeed * 3.6)
        return "Implausible jump between accepted raws (BIG-1032): \(distance) in "
            + String(format: "%.1f s", report.interval) + ", implied \(speed); "
            + "prev " + describe(previous, deliveredAt: previousDeliveredAt) + "; "
            + "cur " + describe(current, deliveredAt: currentDeliveredAt)
    }

    private static func describe(_ location: CLLocation, deliveredAt: Date?) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: location.timestamp)
        let hAcc = String(format: "%.0fm", location.horizontalAccuracy)
        let speed = location.speed < 0 ? "n/a" : String(format: "%.1fm/s", location.speed)
        let course = location.course < 0 ? "n/a" : String(format: "%.0f°", location.course)
        let age = deliveredAt.map { String(format: "%.1fs", $0.timeIntervalSince(location.timestamp)) } ?? "n/a"
        return "\(stamp) hAcc \(hAcc) speed \(speed) course \(course) age \(age)"
    }
}
