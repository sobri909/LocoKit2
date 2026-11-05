//
//  HealthUpdatedTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-05
//

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

/// BIG-963: an item's `healthUpdated` is cleared when its date range moves (a sample-dates registry
/// trigger), and the health pass's write stamps it only while the row still has the range it fetched.
/// HealthKit itself isn't reachable from tests, so the pass is exercised through its write half.
final class HealthUpdatedTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    private static let here = CLLocationCoordinate2D(latitude: 13.75, longitude: 100.55)
    private static let checkedAt = Date(timeIntervalSince1970: 2_000_000_000)

    private struct StagedVisit {
        let id: String
        let start: Date
        let end: Date
        let sampleIds: [String]
    }

    /// A visit of ten samples a minute apart in an empty window, with `healthUpdated` set or cleared.
    private static func stageVisit(stamped: Bool) async throws -> StagedVisit {
        let window = TimelineTestFixtures.freshWindow()
        return try await Database.pool.write { db in
            let item = try TimelineTestFixtures.makeItem(isVisit: true, start: window, count: 10, at: here, db: db)
            try TimelineItemBase
                .filter(key: item.id)
                .updateAll(db, TimelineItemBase.Columns.healthUpdated.set(to: stamped ? Date() : nil))
            let base = try XCTUnwrap(try TimelineItemBase.fetchOne(db, key: item.id))
            let sampleIds = try LocomotionSample
                .filter(LocomotionSample.Columns.timelineItemId == item.id)
                .select(LocomotionSample.Columns.id, as: String.self)
                .fetchAll(db)
            return StagedVisit(id: item.id, start: try XCTUnwrap(base.startDate), end: try XCTUnwrap(base.endDate), sampleIds: sampleIds)
        }
    }

    private static func base(_ itemId: String) async throws -> TimelineItemBase {
        try await Database.pool.read { db in try XCTUnwrap(try TimelineItemBase.fetchOne(db, key: itemId)) }
    }

    /// A sample attached to the item at insert, the way the recorder attaches them.
    private static func insertSample(into itemId: String, at date: Date) async throws {
        try await Database.pool.write { db in
            let location = CLLocation(
                coordinate: here, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 0, timestamp: date
            )
            var sample = LocomotionSample(date: date, movingState: .stationary, recordingState: .recording, location: location)
            sample.timelineItemId = itemId
            try sample.insert(db)
        }
    }

    private static func result(for visit: StagedVisit, steps: Int, heartRates: [String: Double] = [:], complete: Bool = true) -> HealthManager.ItemHealthResult {
        HealthManager.ItemHealthResult(
            itemId: visit.id,
            startDate: visit.start,
            endDate: visit.end,
            stats: HealthManager.HealthStats(
                stepCount: steps, floorsAscended: nil, activeEnergyBurned: nil,
                averageHeartRate: nil, maxHeartRate: nil
            ),
            sampleHeartRates: heartRates,
            complete: complete
        )
    }

    private static let healthTriggerName = "TimelineItemBase_AFTER_UPDATE_dates_healthUpdated"

    private static func healthTriggerExists(in db: GRDB.Database) throws -> Bool {
        try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master WHERE type = 'trigger' AND name = ?",
                         arguments: [healthTriggerName]) == 1
    }

    // MARK: - The trigger

    func testEndMovingClearsHealthUpdated() async throws {
        let visit = try await Self.stageVisit(stamped: true)
        let staged = try await Self.base(visit.id)
        XCTAssertNotNil(staged.healthUpdated, "staging: the visit must start checked")

        try await Self.insertSample(into: visit.id, at: visit.end.addingTimeInterval(60))

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.endDate, visit.end.addingTimeInterval(60), "staging: the sample must move the end")
        XCTAssertNil(after.healthUpdated, "a moved end makes the item's health stale")
    }

    func testStartMovingClearsHealthUpdated() async throws {
        let visit = try await Self.stageVisit(stamped: true)

        try await Self.insertSample(into: visit.id, at: visit.start.addingTimeInterval(-60))

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.startDate, visit.start.addingTimeInterval(-60), "staging: the sample must move the start")
        XCTAssertNil(after.healthUpdated, "a moved start makes the item's health stale")
    }

    func testSampleInsideRangeKeepsHealthUpdated() async throws {
        let visit = try await Self.stageVisit(stamped: true)

        try await Self.insertSample(into: visit.id, at: visit.start.addingTimeInterval(90))

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.startDate, visit.start, "staging: the range must not move")
        XCTAssertEqual(after.endDate, visit.end, "staging: the range must not move")
        XCTAssertTrue(after.samplesChanged, "the insert still marks the item's samples changed")
        XCTAssertNotNil(after.healthUpdated, "the range didn't move, so the stats still describe it")
    }

    // MARK: - The write

    func testStampWrittenWhenRangeUnchanged() async throws {
        let visit = try await Self.stageVisit(stamped: false)

        try await HealthManager.writeHealthResults([Self.result(for: visit, steps: 123)], checkedAt: Self.checkedAt)

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.stepCount, 123)
        XCTAssertEqual(after.healthUpdated, Self.checkedAt, "the fetched range is still the item's, so it is checked")
    }

    /// The range moves while HealthKit is answering. The trigger has nothing to clear (the date is
    /// already nil), so only the write's own condition keeps a stamp off a range nobody fetched.
    func testStampSkippedWhenRangeMovedDuringFetch() async throws {
        let visit = try await Self.stageVisit(stamped: false)
        let fetched = Self.result(for: visit, steps: 123)

        try await Self.insertSample(into: visit.id, at: visit.end.addingTimeInterval(60))
        try await HealthManager.writeHealthResults([fetched], checkedAt: Self.checkedAt)

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.stepCount, 123, "the stats are still written: fresher than what was stored")
        XCTAssertNil(after.healthUpdated, "the stamp would claim a range nobody fetched")
    }

    /// One of the five queries failed: what came back is written, and the item stays unchecked so the
    /// next pass tries again.
    func testIncompleteFetchWritesStatsWithoutStamp() async throws {
        let visit = try await Self.stageVisit(stamped: false)

        try await HealthManager.writeHealthResults([Self.result(for: visit, steps: 123, complete: false)], checkedAt: Self.checkedAt)

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.stepCount, 123)
        XCTAssertNil(after.healthUpdated, "an incomplete fetch must not mark the item checked")
    }

    /// An item kept unchecked by one failing query is fetched again every throttle period while its day is
    /// open; figures that haven't changed must not be rewritten, or each pass bumps its lastSaved (a backup
    /// bucket rewritten, a segment refetch) for nothing.
    func testUnchangedFiguresAreNotRewritten() async throws {
        let visit = try await Self.stageVisit(stamped: false)
        let incomplete = Self.result(for: visit, steps: 123, complete: false)
        try await HealthManager.writeHealthResults([incomplete], checkedAt: Self.checkedAt)

        let backdated = Date(timeIntervalSince1970: 946_684_800)  // 2000-01-01
        try await Database.pool.write { db in
            try TimelineItemBase.filter(key: visit.id).updateAll(db, TimelineItemBase.Columns.lastSaved.set(to: backdated))
        }

        try await HealthManager.writeHealthResults([incomplete], checkedAt: Self.checkedAt)

        let after = try await Self.base(visit.id)
        XCTAssertEqual(after.stepCount, 123)
        XCTAssertEqual(after.lastSaved, backdated, "the same figures again must not touch the row")
    }

    func testHeartRatesWrittenToSamples() async throws {
        let visit = try await Self.stageVisit(stamped: false)
        let sampleId = try XCTUnwrap(visit.sampleIds.first)

        try await HealthManager.writeHealthResults([Self.result(for: visit, steps: 0, heartRates: [sampleId: 72])], checkedAt: Self.checkedAt)

        let heartRate = try await Database.pool.read { db in
            try LocomotionSample.fetchOne(db, key: sampleId)?.heartRate
        }
        XCTAssertEqual(heartRate, 72)
    }

    // MARK: - Installing the trigger

    /// The launch repair runs after migrations whether or not they succeeded. SQLite accepts a trigger
    /// naming a column the table doesn't have, then fails every statement that fires it, so on a table
    /// the column's migration hasn't reached, every date update (every sample write) would fail. On an
    /// in-memory table, so the shared test database is untouched.
    func testHealthTriggerWaitsForItsColumn() throws {
        let trigger = try XCTUnwrap(LocoKit2.Database.triggerDefinitions.first { $0.name == Self.healthTriggerName })
        let queue = try DatabaseQueue()
        try queue.write { db in
            try db.create(table: "TimelineItemBase") { table in
                table.primaryKey("id", .text)
                table.column("startDate", .datetime)
                table.column("endDate", .datetime)
            }

            let createdEarly = try LocoKit2.Database.createIfColumnsPresent(trigger, in: db)
            XCTAssertFalse(createdEarly)
            XCTAssertFalse(try Self.healthTriggerExists(in: db), "no healthUpdated column yet, so no trigger")

            try db.alter(table: "TimelineItemBase") { $0.add(column: "healthUpdated", .datetime) }

            let created = try LocoKit2.Database.createIfColumnsPresent(trigger, in: db)
            XCTAssertTrue(created)
            XCTAssertTrue(try Self.healthTriggerExists(in: db), "the column has landed, so the trigger is created")
        }
    }

}
