//
//  VisitHalfTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-16
//
//  BIG-828: merge scoring fatalErrors on an item whose base says visit and whose visit half is nil.
//  One way to make such an item, read from the code after two crashes on a phone the same afternoon:
//  createItem(isVisit: true) from samples with no usable coordinate. A sample typed bogus has none, and
//  a segment's in-memory samples are still typed bogus when Change Activity turns them stationary and
//  hands them to the extraction.
//
//  The invariant, stated without choosing a fix: creating an item as a visit either gives it a visit
//  half or refuses. A base row that says visit with no visit row must never be the result.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class VisitHalfTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    /// Control: located, stationary samples make a visit with its visit half.
    func testAVisitFromLocatedSamplesHasItsVisitHalf() async throws {
        let outcome = try await createVisit(sampleType: nil)
        XCTAssertEqual(outcome, .visitWithVisitHalf)
    }

    /// The crash's precondition: every sample typed bogus, so none has a usable coordinate.
    func testAVisitFromBogusSamplesIsNeverABaseWithoutItsVisitHalf() async throws {
        let outcome = try await createVisit(sampleType: .bogus)
        XCTAssertNotEqual(outcome, .baseMarkedVisitWithoutVisitHalf,
                          "createItem(isVisit: true) left a base row that says visit with no visit row (BIG-828)")
    }

    /// Rows of this kind already exist on real phones (1,138 live ones in a copy of a 15 Pro's database
    /// from 2026-10-21), so the scorer has to live with them: asked to score a visit against a visit
    /// when one has no visit half, it says the merge is impossible. It used to `fatalError`.
    ///
    /// The two items overlap in time on purpose. With no visit half there is no distance between them,
    /// so the mergeable-distance gate lets the pair through only on a time overlap, and without one the
    /// scorer returns impossible before the line under test (both phone crashes had the overlap: a
    /// bridge merge had just grown the keeper over the item being scored).
    func testScoringAVisitWithNoVisitHalfIsImpossible() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        let (wholeId, halflessId) = try await Database.pool.write { db in
            let whole = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 10, at: coordinate, db: db)
            let halfless = try Self.makeVisitWithNoVisitHalf(start: start.addingTimeInterval(3 * 60), count: 3, at: coordinate, db: db)
            return (whole.id, halfless)
        }

        let whole = try await TimelineItem.fetchItem(itemId: wholeId, includeSamples: true)
        let halfless = try await TimelineItem.fetchItem(itemId: halflessId, includeSamples: true)
        guard let whole, let halfless else { return XCTFail("the two items did not come back") }

        // the preconditions that take a pair as far as the visit ← visit scoring
        XCTAssertTrue(halfless.isVisit)
        XCTAssertNil(halfless.visit, "the fixture is meant to have no visit half")
        XCTAssertNotNil(whole.visit)
        XCTAssertFalse(try halfless.isBogus)
        XCTAssertFalse(try halfless.isNolo)
        XCTAssertLessThan(whole.timeInterval(from: halfless), 0, "the pair has to overlap in time to get past the distance gate")
        XCTAssertTrue(try whole.isWithinMergeableDistance(of: halfless))
        XCTAssertTrue(try halfless.isWithinMergeableDistance(of: whole))

        // the scores cross back as raw values: ConsumptionScore isn't Sendable
        let scores = await Task { @TimelineActor () -> (asConsumee: Int, asConsumer: Int) in
            let asConsumee = await MergeScores.consumptionScoreFor(whole, toConsume: halfless)
            let asConsumer = await MergeScores.consumptionScoreFor(halfless, toConsume: whole)
            return (asConsumee.rawValue, asConsumer.rawValue)
        }.value
        XCTAssertEqual(scores.asConsumee, ConsumptionScore.impossible.rawValue)
        XCTAssertEqual(scores.asConsumer, ConsumptionScore.impossible.rawValue)
    }

    /// The phone's recipe end to end: samples the cleanup button marked bogus, turned stationary from
    /// Individual Segments. The segment the view holds was built before the change, so its samples still
    /// say bogus in memory; the visit the extraction makes has to come from the samples as stored.
    func testTurningABogusSegmentStationaryExtractsAVisitWithACentre() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        // a ten-minute visit whose middle three samples are confirmed bogus
        let hostId = try await Database.pool.write { db in
            let host = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 10, at: coordinate, db: db)
            let middle = try LocomotionSample
                .filter(Column("timelineItemId") == host.id)
                .order(Column("date"))
                .fetchAll(db)[4...6]
            for var sample in middle {
                try sample.updateChanges(db) { $0.confirmedActivityType = .bogus }
            }
            return host.id
        }

        // the segment as the segments list builds it: from the item's samples, read while they are bogus
        let host = try await TimelineItem.fetchItem(itemId: hostId, includeSamples: true)
        let segments = TimelineItem.collateSegments(from: host?.samples ?? [], disabled: false)
        guard let segment = segments.first(where: { $0.activityType == .bogus }) else {
            return XCTFail("no bogus segment in the fixture")
        }
        XCTAssertEqual(segment.samples.count, 3)

        // SegmentTypeView.tapped(activityType: .stationary), minus the view
        await segment.confirmActivityType(.stationary)
        XCTAssertTrue(segment.samples.allSatisfy { $0.activityType == .bogus }, "the held segment's samples are expected to be stale")
        let extractedId = try await TimelineProcessor.extractItem(for: segment, isVisit: true)?.id
        guard let extractedId else { return XCTFail("the extraction returned nothing") }

        // read from the database: processing may since have merged the new item away, its rows stay
        let visitRow = try await Database.pool.read { db in
            try TimelineItemVisit.filter(Column("itemId") == extractedId).fetchOne(db)
        }
        XCTAssertNotNil(visitRow, "the extracted visit has no visit row (BIG-828)")
        XCTAssertNotNil(visitRow?.center, "the extracted visit has no centre: it was built from the segment's stale bogus samples")
    }

    /// What creation does now for samples with no usable coordinate: the visit row is written, with no
    /// centre (the "not yet calculated" state visit coordinates have allowed since BIG-218).
    func testAVisitFromBogusSamplesGetsARowWithNoCentre() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        let visitRow = try await Database.pool.write { db in
            var samples: [LocomotionSample] = []
            for index in 0..<3 {
                let location = CLLocation(
                    coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                    course: 0, speed: 0, timestamp: start.addingTimeInterval(Double(index) * 60)
                )
                var sample = LocomotionSample(
                    date: location.timestamp, movingState: .stationary, recordingState: .recording, location: location
                )
                sample.confirmedActivityType = .bogus
                try sample.insert(db)
                samples.append(sample)
            }
            let item = try TimelineItem.createItem(from: samples, isVisit: true, db: db)
            return try TimelineItemVisit.filter(Column("itemId") == item.id).fetchOne(db)
        }

        XCTAssertNotNil(visitRow)
        XCTAssertNil(visitRow?.center)
    }

    /// The repair for rows real databases already hold: a visit with no visit row gets one when the
    /// processing list loads it, even though nothing has flagged its samples as changed.
    func testAVisitWithNoVisitRowIsRepairedWhenProcessingLoadsIt() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        let halflessId = try await Database.pool.write { db in
            let id = try Self.makeVisitWithNoVisitHalf(start: start, count: 3, at: coordinate, db: db)
            // as a long-settled row is: nothing waiting to be recomputed
            try TimelineItemBase.filter(Column("id") == id).updateAll(db, Column("samplesChanged").set(to: false))
            return id
        }

        let before = try await Database.pool.read { db in
            (flagged: try TimelineItemBase.fetchOne(db, key: halflessId)?.samplesChanged,
             rows: try TimelineItemVisit.filter(Column("itemId") == halflessId).fetchCount(db))
        }
        XCTAssertEqual(before.flagged, false, "the fixture is meant to be unflagged, so only the missing row can bring the repair")
        XCTAssertEqual(before.rows, 0)

        let loadedHasVisit = await Task { @TimelineActor () -> Bool in
            let list = await TimelineLinkedList(fromItemId: halflessId)
            return list?.seedItem?.visit != nil
        }.value
        XCTAssertTrue(loadedHasVisit, "the item the list hands to scoring should carry its visit half")

        let visitRow = try await Database.pool.read { db in
            try TimelineItemVisit.filter(Column("itemId") == halflessId).fetchOne(db)
        }
        XCTAssertNotNil(visitRow, "no visit row was written")
        XCTAssertNotNil(visitRow?.center, "its samples are located and stationary, so the row should have a centre")
    }

    /// The reviewer's shape (2026-11-16): the part of a visit left over after an extraction is made into
    /// its own item, and when that tail is all bogus it used to come out with no visit row too.
    func testAnAllBogusRemainderAfterAnExtractionKeepsItsVisitRow() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        // ten minutes at one spot: four untouched samples, three confirmed walking, three confirmed bogus
        let hostId = try await Database.pool.write { db in
            let host = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 10, at: coordinate, db: db)
            let samples = try LocomotionSample
                .filter(Column("timelineItemId") == host.id)
                .order(Column("date"))
                .fetchAll(db)
            for var sample in samples[4...6] {
                try sample.updateChanges(db) { $0.confirmedActivityType = .walking }
            }
            for var sample in samples[7...9] {
                try sample.updateChanges(db) { $0.confirmedActivityType = .bogus }
            }
            return host.id
        }

        let host = try await TimelineItem.fetchItem(itemId: hostId, includeSamples: true)
        let segments = TimelineItem.collateSegments(from: host?.samples ?? [], disabled: false)
        guard let walking = segments.first(where: { $0.activityType == .walking }) else {
            return XCTFail("no walking segment in the fixture")
        }

        let halflessBefore = try await Self.visitBasesWithNoVisitRow()
        await walking.confirmActivityType(.cycling)
        let extractedId = try await TimelineProcessor.extractItem(for: walking, isVisit: false)?.id
        XCTAssertNotNil(extractedId, "the extraction returned nothing")
        let halflessAfter = try await Self.visitBasesWithNoVisitRow()

        XCTAssertEqual(halflessAfter, halflessBefore, "the extraction left a visit base with no visit row")
    }

    // MARK: -

    /// A base row that says visit, with located stationary samples and no visit row: the shape
    /// `createItem` used to leave behind for samples with no usable coordinate, written here directly.
    private static func makeVisitWithNoVisitHalf(start: Date, count: Int, at coordinate: CLLocationCoordinate2D, db: GRDB.Database) throws -> String {
        let base = TimelineItemBase(isVisit: true)
        try base.insert(db)
        for index in 0..<count {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 0, timestamp: start.addingTimeInterval(Double(index) * 60)
            )
            var sample = LocomotionSample(
                date: location.timestamp, movingState: .stationary, recordingState: .recording, location: location
            )
            try sample.insert(db)
            try sample.updateChanges(db) { $0.timelineItemId = base.id }
        }
        return base.id
    }

    private static func visitBasesWithNoVisitRow() async throws -> Int {
        try await Database.pool.read { db in
            let visitBaseIds = try String.fetchSet(db, TimelineItemBase.select(Column("id")).filter(Column("isVisit") == true))
            let visitRowIds = try String.fetchSet(db, TimelineItemVisit.select(Column("itemId")))
            return visitBaseIds.subtracting(visitRowIds).count
        }
    }

    private enum Outcome: Equatable {
        case visitWithVisitHalf
        case baseMarkedVisitWithoutVisitHalf
        case refused
        case somethingElse
    }

    /// Three samples a minute apart in a fresh window, optionally confirmed as `sampleType`, made into a
    /// visit by `createItem`. The outcome is read back from the database, not from the returned value.
    private func createVisit(sampleType: ActivityType?) async throws -> Outcome {
        let start = TimelineTestFixtures.freshWindow()
        let coordinate = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)

        // counted across the whole table, before and after: a creation that throws part-way inside the
        // write below still commits whatever it had inserted, and returns no id to look the row up by
        let halflessBefore = try await Self.visitBasesWithNoVisitRow()

        let createdId: String? = try await Database.pool.write { db in
            var samples: [LocomotionSample] = []
            for index in 0..<3 {
                let location = CLLocation(
                    coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                    course: 0, speed: 0, timestamp: start.addingTimeInterval(Double(index) * 60)
                )
                var sample = LocomotionSample(
                    date: location.timestamp, movingState: .stationary, recordingState: .recording, location: location
                )
                sample.confirmedActivityType = sampleType
                try sample.insert(db)
                samples.append(sample)
            }
            do {
                return try TimelineItem.createItem(from: samples, isVisit: true, db: db).id
            } catch {
                return nil
            }
        }

        let halflessAfter = try await Self.visitBasesWithNoVisitRow()
        if halflessAfter > halflessBefore { return .baseMarkedVisitWithoutVisitHalf }

        guard let createdId else { return .refused }

        return try await Database.pool.read { db in
            guard let base = try TimelineItemBase.fetchOne(db, key: createdId) else { return .somethingElse }
            let visitRows = try TimelineItemVisit.filter(Column("itemId") == createdId).fetchCount(db)
            if base.isVisit && visitRows == 1 { return .visitWithVisitHalf }
            if base.isVisit && visitRows == 0 { return .baseMarkedVisitWithoutVisitHalf }
            return .somethingElse
        }
    }
}
