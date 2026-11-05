//
//  StaleTripProcessingTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-05
//
//  BIG-308: the recorder creates a trip from its first sample (stored distance 0) and attaches the
//  rest without refreshing the trip's derived fields; only `updateFrom(samples:)` does that, and the
//  processing list's load path doesn't call it. `isValid` reads the stored distance, so a trip that
//  reaches scoring stale reads as invalid and a neighbouring visit can swallow it. These stage the
//  recorder's shape directly, with edges placed so nothing is stolen (a steal would refresh the trip
//  through the list's observer), and run processing the way the recorder does on sleep.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class StaleTripProcessingTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    /// A trip built the recorder's way: created from one sample, 29 more attached afterwards. It covers
    /// about 1.9 km, so fresh it's a keeper. Stale, its stored distance is 0 and it reads as invalid.
    func testRecorderBuiltTripSurvivesProcessing() async throws {
        let staged = try await Self.stage(recorderWay: true)

        let (storedDistance, samplesChanged) = try await Database.pool.read { db in
            (try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == staged.tripId).fetchOne(db)?.distance,
             try TimelineItemBase.fetchOne(db, key: staged.tripId)?.samplesChanged)
        }
        XCTAssertEqual(storedDistance, 0, "staging: the recorder's trip must carry its one-sample distance")
        XCTAssertEqual(samplesChanged, true, "staging: attaching samples must mark the trip stale")

        try await Self.runProcessFrom(itemId: staged.lastVisitId)
        try await Self.assertTripSurvived(staged)

        // the refresh is written once (BIG-963 made that safe), not repeated at every load
        let (refreshedDistance, stillStale) = try await Database.pool.read { db in
            (try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == staged.tripId).fetchOne(db)?.distance,
             try TimelineItemBase.fetchOne(db, key: staged.tripId)?.samplesChanged)
        }
        XCTAssertGreaterThan(refreshedDistance ?? 0, 1_000, "the load refresh must write the trip's real distance")
        XCTAssertEqual(stillStale, false, "the load refresh must clear the flag, so the next load doesn't repeat it")
    }

    /// Control: the same trip, built with all its samples at once, so its stored distance is real.
    func testFullyBuiltTripSurvivesProcessing() async throws {
        let staged = try await Self.stage(recorderWay: false)

        let storedDistance = try await Database.pool.read { db in
            try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == staged.tripId).fetchOne(db)?.distance
        }
        XCTAssertGreaterThan(storedDistance ?? 0, 1_000, "staging: the control trip must carry its real distance")

        try await Self.runProcessFrom(itemId: staged.lastVisitId)
        try await Self.assertTripSurvived(staged)
    }

    // MARK: - Staging

    private struct Staged {
        let firstVisitId: String
        let tripId: String
        let lastVisitId: String
        let witnessId: String
        let tripSampleCount: Int
    }

    /// Keeper visit A (15 min) → trip (30 samples, 20 s apart, 10 min) → keeper visit B (15 min), linked.
    /// The trip starts and ends ~60 m from its visits: inside the 150 m visit↔trip mergeable distance,
    /// outside the single-point visits' radius, so the merge is possible and nothing is stolen.
    private static func stage(recorderWay: Bool) async throws -> Staged {
        let base = TimelineTestFixtures.freshWindow()
        let lat = 13.75
        let lonA = 100.55
        let lonB = lonA + 0.0185          // ~2 km east at this latitude
        let edgeOffset = 0.00055          // ~60 m

        return try await Database.pool.write { db in
            let visitA = try TimelineTestFixtures.makeItem(
                isVisit: true, start: base, count: 15,
                at: CLLocationCoordinate2D(latitude: lat, longitude: lonA), db: db
            )

            let tripStart = base.addingTimeInterval(15 * 60)
            let pointCount = 30
            let interval: TimeInterval = 20
            let points: [CLLocationCoordinate2D] = (0..<pointCount).map { index in
                let fraction = Double(index) / Double(pointCount - 1)
                let lon = (lonA + edgeOffset) + fraction * ((lonB - edgeOffset) - (lonA + edgeOffset))
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            let trip = recorderWay
                ? try makeRecorderTrip(start: tripStart, interval: interval, points: points, db: db)
                : try TimelineTestFixtures.makeTrip(start: tripStart, interval: interval, points: points, type: nil, db: db)

            let visitBStart = tripStart.addingTimeInterval(Double(pointCount) * interval)
            let visitB = try TimelineTestFixtures.makeItem(
                isVisit: true, start: visitBStart, count: 15,
                at: CLLocationCoordinate2D(latitude: lat, longitude: lonB), db: db
            )

            // a one-sample visit after B, which processing always merges: proof that processing ran,
            // so a surviving trip can't mean the pass returned early (reviewer, 2026-11-05)
            let witness = try TimelineTestFixtures.makeItem(
                isVisit: true, start: visitBStart.addingTimeInterval(15 * 60), count: 1,
                at: CLLocationCoordinate2D(latitude: lat, longitude: lonB), db: db
            )

            try TimelineTestFixtures.link(db, visitA.id, trip.id, visitB.id, witness.id)
            return Staged(firstVisitId: visitA.id, tripId: trip.id, lastVisitId: visitB.id, witnessId: witness.id, tripSampleCount: pointCount)
        }
    }

    /// The recorder's way (`TimelineRecorder.createTimelineItem` then `processSample`): the item is created
    /// from the first sample, and each later sample is attached by setting its `timelineItemId`, with no
    /// refresh of the trip's derived fields.
    private static func makeRecorderTrip(start: Date, interval: TimeInterval, points: [CLLocationCoordinate2D], db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for (index, coordinate) in points.enumerated() {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 90, speed: 3.2, timestamp: start.addingTimeInterval(Double(index) * interval)
            )
            let sample = LocomotionSample(date: location.timestamp, movingState: .moving, recordingState: .recording, location: location)
            try sample.insert(db)
            samples.append(sample)
        }
        let item = try TimelineItem.createItem(from: [samples[0]], isVisit: false, db: db)
        for var sample in samples.dropFirst() {
            try sample.updateChanges(db) { $0.timelineItemId = item.id }
        }
        return item
    }

    // MARK: - Running and checking

    private static func runProcessFrom(itemId: String, timeout: TimeInterval = 60) async throws {
        let done = XCTestExpectation(description: "TimelineProcessor.processFrom returned")
        let task = Task { @TimelineActor in
            await TimelineProcessor.processFrom(itemId: itemId)
            done.fulfill()
        }
        let outcome = await XCTWaiter().fulfillment(of: [done], timeout: timeout)
        if outcome != .completed {
            task.cancel()
            XCTFail("TimelineProcessor.processFrom did not return within \(Int(timeout)) s")
        }
    }

    private static func assertTripSurvived(_ staged: Staged, file: StaticString = #filePath, line: UInt = #line) async throws {
        let (witnessDeleted, tripDeleted, tripSamples, visitADeleted, visitBDeleted) = try await Database.pool.read { db in
            (try TimelineItemBase.fetchOne(db, key: staged.witnessId)?.deleted,
             try TimelineItemBase.fetchOne(db, key: staged.tripId)?.deleted,
             try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == staged.tripId).fetchCount(db),
             try TimelineItemBase.fetchOne(db, key: staged.firstVisitId)?.deleted,
             try TimelineItemBase.fetchOne(db, key: staged.lastVisitId)?.deleted)
        }
        XCTAssertEqual(witnessDeleted, true, "processing must have run: the one-sample witness wasn't merged", file: file, line: line)
        XCTAssertEqual(tripDeleted, false, "the ~1.9 km trip must not be merged away", file: file, line: line)
        XCTAssertEqual(tripSamples, staged.tripSampleCount, "the trip must keep its samples", file: file, line: line)
        XCTAssertEqual(visitADeleted, false, file: file, line: line)
        XCTAssertEqual(visitBDeleted, false, file: file, line: line)
    }
}
