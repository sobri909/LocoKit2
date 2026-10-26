//
//  LockedVisitDeleteTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-10-26
//
//  BIG-908: deleting a visit is the user's explicit instruction, and imported items are locked (GPX
//  waypoints today; workout pause visits under BIG-232). safeDeleteVisit must remove the visit whether
//  the lock is on the visit, on its neighbours, or on all three. Real schema and triggers, on the
//  simulator's test host.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class LockedVisitDeleteTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    /// Control: nothing locked.
    func testDeletingAVisitBetweenUnlockedTrips() async throws {
        try await assertDeleteRemovesTheVisit(tripsLocked: false, visitLocked: false)
    }

    /// A GPX waypoint imported into recorded data: unlocked trip -> locked visit -> unlocked trip.
    func testDeletingALockedVisitBetweenUnlockedTrips() async throws {
        try await assertDeleteRemovesTheVisit(tripsLocked: false, visitLocked: true)
    }

    /// A workout pause the user changed to stationary: locked trip -> unlocked visit -> locked trip.
    func testDeletingAnUnlockedVisitBetweenLockedTrips() async throws {
        try await assertDeleteRemovesTheVisit(tripsLocked: true, visitLocked: false)
    }

    /// A workout pause imported as a visit (BIG-232): locked trip -> locked visit -> locked trip.
    func testDeletingALockedVisitBetweenLockedTrips() async throws {
        try await assertDeleteRemovesTheVisit(tripsLocked: true, visitLocked: true)
    }

    /// Locks must not change the outcome of a delete, only allow it. A keeper trip ~80 m away and a valid
    /// non-keeper trip ~5 m away, same type: scored, the delete bridges them into one trip holding
    /// everything (which of the two equal-scoring bridges wins doesn't matter: same samples, same type).
    /// With only the scoring override missing, the distance-ranked fallback would give the visit to
    /// the nearer trip and leave two. Unlocked and locked must agree; the survivor keeps its lock.
    func testLocksDoNotChangeTheOutcomeOfADelete() async throws {
        for locked in [false, true] {
            let result = try await deleteVisitBetweenTrips(
                locked: locked,
                before: (interval: 60, points: (0..<12).map { CLLocationCoordinate2D(latitude: 24.0750 + Double($0) * 0.000845, longitude: 32.8950) }),
                after: (interval: 10, points: (0..<3).map { CLLocationCoordinate2D(latitude: 24.08505 + Double($0) * 0.00012, longitude: 32.8950) })
            )
            let shape = locked ? "locked" : "unlocked"
            XCTAssertTrue(result.visitDeleted, "\(shape): the visit should be gone")
            XCTAssertEqual(result.liveTrips, 1, "\(shape): the delete should leave one trip")
            XCTAssertEqual(result.samplesInSurvivor, 21, "\(shape): the surviving trip should hold every sample")
            XCTAssertEqual(result.survivorLocked, locked, "\(shape): the surviving trip keeps the lock it had")
        }
    }

    /// A workout split at a pause, the pause deleted: the two ride segments either side should join into
    /// one item, locked as they were, exactly as the same shape does unlocked. Needs the bridge to score,
    /// which needs trip-to-trip distance across the betweener (`edgeSample(facing:)`).
    func testDeletingAPauseBetweenTwoRideSegmentsJoinsThem() async throws {
        for locked in [false, true] {
            let result = try await deleteVisitBetweenTrips(
                locked: locked,
                before: (interval: 60, points: (0..<12).map { CLLocationCoordinate2D(latitude: 24.0749 + Double($0) * 0.00091, longitude: 32.8950) }),
                after: (interval: 60, points: (0..<12).map { CLLocationCoordinate2D(latitude: 24.0851 + Double($0) * 0.00091, longitude: 32.8950) })
            )
            let shape = locked ? "locked" : "unlocked"
            XCTAssertTrue(result.visitDeleted, "\(shape): the pause should be gone")
            XCTAssertEqual(result.liveTrips, 1, "\(shape): the two ride segments should have joined into one")
            XCTAssertEqual(result.samplesInSurvivor, 30, "\(shape): the surviving ride should hold every sample")
            XCTAssertEqual(result.survivorLocked, locked, "\(shape): the surviving ride keeps the lock it had")
        }
    }

    /// A visit between an unlocked trip and a locked one: a bridge would decide which survives, and so
    /// whether recorded samples end up inside the import's lock, by sort order. Refused; an adjacent
    /// merge takes the visit and both trips stay.
    func testDeletingAVisitBetweenALockedAndAnUnlockedTripKeepsBoth() async throws {
        let result = try await deleteVisitBetweenTrips(
            locked: false, lockSecond: true,
            before: (interval: 60, points: (0..<12).map { CLLocationCoordinate2D(latitude: 24.0749 + Double($0) * 0.00091, longitude: 32.8950) }),
            after: (interval: 60, points: (0..<12).map { CLLocationCoordinate2D(latitude: 24.0851 + Double($0) * 0.00091, longitude: 32.8950) })
        )
        XCTAssertTrue(result.visitDeleted, "the visit should be gone")
        XCTAssertEqual(result.liveTrips, 2, "a bridge must not join a locked trip to an unlocked one")
    }

    /// Normal processing must not bridge two trips across a data gap: the gap is real, and the bridge
    /// would not score its middle item. Possible once trip-to-trip distance reached across a betweener.
    func testProcessingKeepsADataGapBetweenTwoTrips() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let gapStart = CLLocationCoordinate2D(latitude: 24.0850, longitude: 32.8950)
        let before = (0..<12).map { CLLocationCoordinate2D(latitude: 24.0749 + Double($0) * 0.00091, longitude: 32.8950) }
        let after = (0..<12).map { CLLocationCoordinate2D(latitude: 24.0851 + Double($0) * 0.00091, longitude: 32.8950) }

        let ids = try await Database.pool.write { db -> [String] in
            let first = try TimelineTestFixtures.makeTrip(start: base, interval: 60, points: before, type: .cycling, db: db)
            let gap = try TimelineTestFixtures.makeDataGap(start: base.addingTimeInterval(11 * 60 + 30), duration: 30 * 60, at: gapStart, db: db)
            let second = try TimelineTestFixtures.makeTrip(start: base.addingTimeInterval(42 * 60), interval: 60, points: after, type: .cycling, db: db)
            try TimelineTestFixtures.link(db, first.id, gap.id, second.id)
            return [first.id, gap.id, second.id]
        }

        let done = XCTestExpectation(description: "process returned")
        Task { @TimelineActor in
            let list = await TimelineLinkedList(fromItemIds: ids)
            await TimelineProcessor.process(list)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 60)

        let live = try await Database.pool.read { db in
            try TimelineItemBase
                .filter(ids.contains(TimelineItemBase.Columns.id))
                .filter(TimelineItemBase.Columns.deleted == false)
                .fetchAll(db)
                .map(\.id)
        }
        XCTAssertTrue(live.contains(ids[1]), "the data gap should survive processing")
        XCTAssertEqual(live.count, 3, "both trips and the gap should remain")
    }

    /// Which end faces the other item: the linked edge, or by time order when the two aren't linked.
    func testEdgeSampleFacingPicksTheEndsThatFaceEachOther() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let points = (0..<6).map { CLLocationCoordinate2D(latitude: 24.07 + Double($0) * 0.001, longitude: 32.89) }
        let (earlierId, laterId) = try await Database.pool.write { db -> (String, String) in
            let earlier = try TimelineTestFixtures.makeTrip(start: base, interval: 60, points: points, type: .walking, db: db)
            let later = try TimelineTestFixtures.makeTrip(start: base.addingTimeInterval(60 * 60), interval: 60, points: points, type: .walking, db: db)
            return (earlier.id, later.id)
        }

        func check(_ label: String) async throws {
            guard let earlier = try await TimelineItem.fetchItem(itemId: earlierId, includeSamples: true),
                  let later = try await TimelineItem.fetchItem(itemId: laterId, includeSamples: true) else {
                XCTFail("\(label): staging"); return
            }
            XCTAssertEqual(try earlier.edgeSample(facing: later)?.id, earlier.samples?.last?.id, "\(label): the earlier item faces with its last sample")
            XCTAssertEqual(try later.edgeSample(facing: earlier)?.id, later.samples?.first?.id, "\(label): the later item faces with its first sample")
        }

        try await check("unlinked")
        try await Database.pool.write { db in try TimelineTestFixtures.link(db, earlierId, laterId) }
        try await check("linked")
    }

    // MARK: - Helpers

    /// Cycling trip through `before` -> six-sample visit at the stop -> cycling trip through `after`, all
    /// locked or none, linked; deletes the visit and reports what is left of the two trips.
    private func deleteVisitBetweenTrips(
        locked: Bool,
        lockSecond: Bool? = nil,
        before: (interval: TimeInterval, points: [CLLocationCoordinate2D]),
        after: (interval: TimeInterval, points: [CLLocationCoordinate2D])
    ) async throws -> (visitDeleted: Bool, liveTrips: Int, samplesInSurvivor: Int, survivorLocked: Bool?) {
        let base = TimelineTestFixtures.freshWindow()
        let stop = CLLocationCoordinate2D(latitude: 24.0850, longitude: 32.8950)
        let beforeEnd = Double(before.points.count - 1) * before.interval

        let (firstId, visitId, secondId) = try await Database.pool.write { db -> (String, String, String) in
            let first = try TimelineTestFixtures.makeTrip(start: base, interval: before.interval, points: before.points, type: .cycling, locked: locked, db: db)
            let visit = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(beforeEnd + 60), count: 6, at: stop, locked: locked, db: db)
            let second = try TimelineTestFixtures.makeTrip(start: base.addingTimeInterval(beforeEnd + 7 * 60), interval: after.interval, points: after.points, type: .cycling, locked: lockSecond ?? locked, db: db)
            try TimelineTestFixtures.link(db, first.id, visit.id, second.id)
            return (first.id, visit.id, second.id)
        }

        guard let visit = try await TimelineItem.fetchItem(itemId: visitId, includeSamples: true) else {
            XCTFail("staging: the visit should exist")
            return (false, 0, 0, nil)
        }
        await TimelineProcessor.safeDeleteVisit(visit)

        return try await Database.pool.read { db in
            let deleted = try TimelineItemBase.fetchOne(db, key: visitId)?.deleted == true
            let live = try TimelineItemBase
                .filter([firstId, secondId].contains(TimelineItemBase.Columns.id))
                .filter(TimelineItemBase.Columns.deleted == false)
                .fetchAll(db)
            guard live.count == 1, let survivor = live.first else { return (deleted, live.count, 0, nil) }
            let count = try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == survivor.id).fetchCount(db)
            return (deleted, 1, count, survivor.locked)
        }
    }

    /// Trip (12 samples) -> visit (6 samples) -> trip (12 samples), deletes the visit, and checks that it
    /// is gone and that all 30 samples still belong to a live neighbour.
    private func assertDeleteRemovesTheVisit(
        tripsLocked: Bool,
        visitLocked: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let base = TimelineTestFixtures.freshWindow()
        let start = CLLocationCoordinate2D(latitude: 24.08, longitude: 32.89)
        let stop = CLLocationCoordinate2D(latitude: 24.085, longitude: 32.895)
        let end = CLLocationCoordinate2D(latitude: 24.09, longitude: 32.90)

        let ids = try await Database.pool.write { db -> [String] in
            let before = try TimelineTestFixtures.makeItem(isVisit: false, start: base, count: 12, at: start, locked: tripsLocked, db: db)
            let visit = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(13 * 60), count: 6, at: stop, locked: visitLocked, db: db)
            let after = try TimelineTestFixtures.makeItem(isVisit: false, start: base.addingTimeInterval(20 * 60), count: 12, at: end, locked: tripsLocked, db: db)
            try TimelineTestFixtures.link(db, before.id, visit.id, after.id)
            return [before.id, visit.id, after.id]
        }

        guard let visit = try await TimelineItem.fetchItem(itemId: ids[1], includeSamples: true) else {
            XCTFail("staging: the visit should exist", file: file, line: line)
            return
        }
        await TimelineProcessor.safeDeleteVisit(visit)

        let (visitDeleted, liveSamples) = try await Database.pool.read { db in
            let deleted = try TimelineItemBase.fetchOne(db, key: ids[1])?.deleted
            let liveIds = try TimelineItemBase
                .filter(ids.contains(TimelineItemBase.Columns.id))
                .filter(TimelineItemBase.Columns.deleted == false)
                .fetchAll(db)
                .map(\.id)
            let count = try LocomotionSample
                .filter(liveIds.contains(LocomotionSample.Columns.timelineItemId))
                .fetchCount(db)
            return (deleted, count)
        }
        let shape = "trips \(tripsLocked ? "locked" : "unlocked"), visit \(visitLocked ? "locked" : "unlocked")"
        XCTAssertEqual(visitDeleted, true, "\(shape): the visit should be gone after the user deletes it", file: file, line: line)
        XCTAssertEqual(liveSamples, 30, "\(shape): every sample should still belong to a live item", file: file, line: line)
    }
}
