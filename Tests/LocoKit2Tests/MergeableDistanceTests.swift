//
//  MergeableDistanceTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-07
//
//  BIG-631: the visit<->trip mergeable distance was meant to forgive a gap a trip could have covered
//  in the time between the two items, `speed * timeSeparation * 4` (AT3's formula since before 2018),
//  floored at 150 m. `??` binds looser than `*`, so `speed ?? 0 * timeSeparation * 4` parsed as
//  `speed ?? (0 * ...)`: the allowance was the trip's speed in metres, and the gate sat at the 150 m
//  floor for every visit<->trip pair. These pin the intended formula on both sides of the floor.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class MergeableDistanceTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    private static let base = CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633)

    /// `metres` north of the base coordinate (1° of latitude ≈ 111,320 m).
    private static func north(_ metres: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: base.latitude + metres / 111_320, longitude: base.longitude)
    }

    /// A ten-sample visit at the base, then a trip starting ten minutes after it ends, 400 m north.
    /// `tripMetres` is the trip's own length over its 60 s, which sets its stored speed.
    private static func stage(tripMetres: Double) async throws -> (visit: TimelineItem, trip: TimelineItem) {
        let start = TimelineTestFixtures.freshWindow()
        let visitEnd = start.addingTimeInterval(9 * 60)
        let (visitId, tripId) = try await Database.pool.write { db in
            let visit = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 10, at: base, db: db)
            let points = (0..<5).map { north(400 + tripMetres * Double($0) / 4) }
            let trip = try TimelineTestFixtures.makeTrip(start: visitEnd.addingTimeInterval(600), interval: 15, points: points, type: .walking, db: db)
            try TimelineTestFixtures.link(db, visit.id, trip.id)
            return (visit.id, trip.id)
        }
        guard let visit = try await TimelineItem.fetchItem(itemId: visitId, includeSamples: true),
              let trip = try await TimelineItem.fetchItem(itemId: tripId, includeSamples: true) else {
            throw TimelineError.itemNotFound
        }
        return (visit, trip)
    }

    /// 100 m in 60 s is 1.67 m/s; ten minutes of that, times four, is 4 km of forgiveness, so a 400 m
    /// gap is mergeable. Under the parse bug the allowance was 1.67 "metres" and the floor held at 150.
    func testFastTripTenMinutesAwayIsWithinMergeableDistance() async throws {
        let staged = try await Self.stage(tripMetres: 100)
        let speed = staged.trip.trip?.speed ?? 0
        XCTAssertGreaterThan(speed, 1.0, "staging: the trip must carry a real speed")
        let gap = try staged.visit.distance(from: staged.trip) ?? -1
        XCTAssertGreaterThan(gap, 150, "staging: the gap must be past the 150 m floor")

        XCTAssertTrue(try staged.visit.isWithinMergeableDistance(of: staged.trip), "visit -> trip: speed × 600 s × 4 must forgive 400 m")
        XCTAssertTrue(try staged.trip.isWithinMergeableDistance(of: staged.visit), "trip -> visit is the same gate")
    }

    /// 8 m in 60 s is 0.13 m/s; ten minutes of that, times four, is 320 m, under the 400 m gap, so the
    /// floor is what applies and the pair stays apart. The fix widens the gate for fast trips only.
    func testSlowTripTenMinutesAwayStaysOutsideMergeableDistance() async throws {
        let staged = try await Self.stage(tripMetres: 8)
        let speed = staged.trip.trip?.speed ?? 0
        XCTAssertLessThan(speed, 0.2, "staging: the trip must be slow")

        XCTAssertFalse(try staged.visit.isWithinMergeableDistance(of: staged.trip), "a slow trip's allowance stays under the gap")
        XCTAssertFalse(try staged.trip.isWithinMergeableDistance(of: staged.visit))
    }
}
