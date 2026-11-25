//
//  RawFixJumpCheckTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-25
//
//  BIG-1032: the instrument that names a pair of consecutive accepted raw fixes no vehicle could
//  connect while both claim good accuracy. Pure, no database. Each threshold is pinned from both
//  sides, and the log line is checked for carrying no coordinates.

import XCTest
import CoreLocation
@testable import LocoKit2

final class RawFixJumpCheckTests: XCTestCase {

    private static let t0 = Date(timeIntervalSince1970: 1_764_000_000)  // 2025-11-24T16:00:00Z (`date -u -r 1764000000`)
    private static let lat = 51.5074
    private static let lon = -0.1278

    /// `northMetres` north of the base point (1° of latitude ≈ 111,320 m), at `t0 + seconds`.
    private static func fix(northMetres: Double = 0, seconds: TimeInterval = 0, hAcc: CLLocationAccuracy = 10,
                            speed: CLLocationSpeed = 24.8, course: CLLocationDirection = 187) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat + northMetres / 111_320, longitude: lon),
                   altitude: 0, horizontalAccuracy: hAcc, verticalAccuracy: 5,
                   course: course, speed: speed, timestamp: t0.addingTimeInterval(seconds))
    }

    // MARK: - Fires

    func testFarJumpInOneSecondFires() throws {
        let report = try XCTUnwrap(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 11_132, seconds: 1)))
        XCTAssertEqual(report.distance, 11_132, accuracy: 20)
        XCTAssertEqual(report.interval, 1, accuracy: 0.001)
        XCTAssertGreaterThan(report.impliedSpeed, 10_000)
    }

    func testJumpJustPastTheFloorAtImplausibleSpeedFires() {
        // 600 m in 1 s is 600 m/s, past the floor and past the speed bound.
        XCTAssertNotNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 600, seconds: 1)))
    }

    // MARK: - Does not fire

    func testPlausibleSpeedDoesNotFire() {
        // 11.1 km in 60 s is 185 m/s, under 1,500 km/h; so is an airliner's 2.5 km in 10 s (both past the floor).
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 11_132, seconds: 60)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 2_500, seconds: 10)))
    }

    func testSpeedBoundIsPinnedFromBothSides() {
        // The bound is 416.7 m/s. 5 km (geodesic ~4,997 m) in 12.5 s is 400 m/s; in 11.5 s it is 435 m/s.
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 5_000, seconds: 12.5)))
        XCTAssertNotNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 5_000, seconds: 11.5)))
    }

    func testAccuracyBoundIsPinnedFromBothSides() {
        XCTAssertNotNil(RawFixJumpCheck.report(previous: Self.fix(hAcc: 99), current: Self.fix(northMetres: 11_132, seconds: 1, hAcc: 99)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(hAcc: 99), current: Self.fix(northMetres: 11_132, seconds: 1, hAcc: 100)))
    }

    func testDistanceFloorIsPinnedFromBothSides() {
        // Both pairs are 1 s apart at ~490 and ~510 m/s, past the speed bound; only the floor separates them.
        // (A staged 500 m comes out as 499.7 m geodesic, so the pins sit 10 m either side.)
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 490, seconds: 1)))
        XCTAssertNotNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 510, seconds: 1)))
    }

    func testPoorAccuracyOnEitherSideDoesNotFire() {
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(hAcc: 150), current: Self.fix(northMetres: 11_132, seconds: 1)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 11_132, seconds: 1, hAcc: 150)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(hAcc: 100), current: Self.fix(northMetres: 11_132, seconds: 1)),
                     "the bound is exclusive: exactly 100 m is not good accuracy")
    }

    func testInvalidAccuracyDoesNotFire() {
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(hAcc: -1), current: Self.fix(northMetres: 11_132, seconds: 1)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 11_132, seconds: 1, hAcc: -1)))
    }

    func testDistanceFloorDoesNotFireOnJitter() {
        // 5 m in 10 ms is 500 m/s, past the 416.7 m/s speed bound, under the 500 m floor.
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 5, seconds: 0.01)))
    }

    func testOutOfOrderOrSimultaneousDoesNotFire() {
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(seconds: 1), current: Self.fix(northMetres: 11_132, seconds: 0)))
        XCTAssertNil(RawFixJumpCheck.report(previous: Self.fix(), current: Self.fix(northMetres: 11_132, seconds: 0)))
    }

    // MARK: - The line

    func testLogLineCarriesTheFieldsAndNoCoordinates() throws {
        let previous = Self.fix()
        let current = Self.fix(northMetres: 11_132, seconds: 1, hAcc: 9, speed: 24.8, course: 251)
        let report = try XCTUnwrap(RawFixJumpCheck.report(previous: previous, current: current))
        let line = RawFixJumpCheck.logLine(report, previous: previous, current: current,
                                           previousDeliveredAt: previous.timestamp.addingTimeInterval(0.2),
                                           currentDeliveredAt: current.timestamp.addingTimeInterval(0.1))

        XCTAssertTrue(line.contains("BIG-1032"), line)
        XCTAssertTrue(line.contains("11.1 km in 1.0 s"), line)
        XCTAssertTrue(line.contains("km/h"), line)
        XCTAssertTrue(line.contains("prev 2025-11-24T16:00:00.000Z hAcc 10m speed 24.8m/s course 187° age 0.2s"), line)
        XCTAssertTrue(line.contains("cur 2025-11-24T16:00:01.000Z hAcc 9m speed 24.8m/s course 251° age 0.1s"), line)

        for fragment in ["51.5", "51.6", "0.1278", "0.128", "-0.12", "-0.13", "latitude", "longitude"] {
            XCTAssertFalse(line.contains(fragment), "coordinate fragment \(fragment) in: \(line)")
        }
    }

    func testLogLineNamesUnknownsAsNotAvailable() throws {
        let previous = Self.fix(speed: -1, course: -1)
        let current = Self.fix(northMetres: 11_132, seconds: 1)
        let report = try XCTUnwrap(RawFixJumpCheck.report(previous: previous, current: current))
        let line = RawFixJumpCheck.logLine(report, previous: previous, current: current,
                                           previousDeliveredAt: nil, currentDeliveredAt: current.timestamp)
        XCTAssertTrue(line.contains("prev 2025-11-24T16:00:00.000Z hAcc 10m speed n/a course n/a age n/a"), line)
        XCTAssertTrue(line.contains("age 0.0s"), line)
    }
}
