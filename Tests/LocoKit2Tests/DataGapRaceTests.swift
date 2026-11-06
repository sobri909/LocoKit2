//
//  DataGapRaceTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-06
//
//  BIG-793: two concurrent edge heals can decide the same data gap from reads that completed before
//  either wrote (the actor serialises only between suspension points), and the second write created a
//  twin gap item that the edge triggers then left dangling, still rendering in the day view. The fix
//  re-reads both endpoints inside the gap creator's write and refuses when an edge has moved since the
//  heal's read. The race itself isn't staged here; the loser's situation is: a write from copies whose
//  edges are stale because the other heal has already landed.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class DataGapRaceTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    private static let coordinate = CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633)

    /// The loser's write: both heals read `a` and `b` with nil edges; the first write lands and the
    /// triggers link a → gap → b; the second write, from the same stale copies, must refuse and leave
    /// one gap.
    func testSecondGapWriteFromStaleReadsIsRefused() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let (a, b) = try await Database.pool.write { db in
            let a = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 5, at: Self.coordinate, db: db)
            let b = try TimelineTestFixtures.makeItem(isVisit: true, start: start.addingTimeInterval(3600), count: 5, at: Self.coordinate, db: db)
            return (a, b)
        }
        XCTAssertNil(a.base.nextItemId, "staging: a has no next edge")
        XCTAssertNil(b.base.previousItemId, "staging: b has no previous edge")
        let itemsBefore = try await Self.itemCount(around: start)

        let firstWrite = try await TimelineProcessor.createDataGapItem(between: a, and: b)
        XCTAssertTrue(firstWrite, "the first write creates the gap")
        let gapId = try await Self.edges(of: a.id).next
        XCTAssertNotNil(gapId, "a's next edge is the gap")
        let bPrevious = try await Self.edges(of: b.id).previous
        XCTAssertEqual(bPrevious, gapId, "b's previous edge is the same gap")
        let itemsAfterFirst = try await Self.itemCount(around: start)
        XCTAssertEqual(itemsAfterFirst, itemsBefore + 1)

        // the other heal, writing from the copies it read before the first write landed
        let secondWrite = try await TimelineProcessor.createDataGapItem(between: a, and: b)
        XCTAssertFalse(secondWrite, "the second write must see the moved edges and refuse")
        let itemsAfterSecond = try await Self.itemCount(around: start)
        XCTAssertEqual(itemsAfterSecond, itemsBefore + 1, "no twin gap")
        let aNextAfter = try await Self.edges(of: a.id).next
        XCTAssertEqual(aNextAfter, gapId, "a's edge is untouched")
        let bPreviousAfter = try await Self.edges(of: b.id).previous
        XCTAssertEqual(bPreviousAfter, gapId, "b's edge is untouched")
    }

    /// Control, so the re-check can't over-refuse: a heal that read the current edges proceeds, including
    /// the steal case where the first item already has a farther neighbour. `a` is linked to `c` five
    /// hours on; `b`, an hour after `a`, is closer, so healing b's previous edge creates a gap between
    /// a and b having read a.next == c.
    func testGapWriteFromCurrentReadsProceedsIncludingSteal() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let (aId, b, cId) = try await Database.pool.write { db in
            let a = try TimelineTestFixtures.makeItem(isVisit: true, start: start, count: 5, at: Self.coordinate, db: db)
            let b = try TimelineTestFixtures.makeItem(isVisit: true, start: start.addingTimeInterval(3600), count: 5, at: Self.coordinate, db: db)
            let c = try TimelineTestFixtures.makeItem(isVisit: true, start: start.addingTimeInterval(5 * 3600), count: 5, at: Self.coordinate, db: db)
            try TimelineTestFixtures.link(db, a.id, c.id)
            return (a.id, b, c.id)
        }
        guard let a = try await TimelineItem.fetchItem(itemId: aId, includeSamples: false) else {
            return XCTFail("staging: a not found")
        }
        XCTAssertEqual(a.base.nextItemId, cId, "staging: a's next edge is c, as the heal would read it")
        XCTAssertNil(b.base.previousItemId, "staging: b has no previous edge")
        let itemsBefore = try await Self.itemCount(around: start)

        let created = try await TimelineProcessor.createDataGapItem(between: a, and: b)
        XCTAssertTrue(created, "a write from current reads proceeds, steal included")
        let itemsAfter = try await Self.itemCount(around: start)
        XCTAssertEqual(itemsAfter, itemsBefore + 1, "one gap created")
        let gapId = try await Self.edges(of: a.id).next
        XCTAssertNotNil(gapId)
        XCTAssertNotEqual(gapId, cId, "a's next edge moved from c to the gap")
        let bPrevious = try await Self.edges(of: b.id).previous
        XCTAssertEqual(bPrevious, gapId)
        let cPrevious = try await Self.edges(of: cId).previous
        XCTAssertNil(cPrevious, "the trigger cleared c's previous edge, which pointed at a; that is what makes the steal correct")
        if let gapId {
            let gapEdges = try await Self.edges(of: gapId)
            XCTAssertEqual(gapEdges.previous, a.id)
            XCTAssertEqual(gapEdges.next, b.id)
        }
    }

    // MARK: - Helpers

    private static func edges(of id: String) async throws -> (previous: String?, next: String?) {
        try await Database.pool.read { db in
            guard let base = try TimelineItemBase.fetchOne(db, key: id) else { throw TimelineError.itemNotFound }
            return (base.previousItemId, base.nextItemId)
        }
    }

    /// Items in the test's window (a day before to three days after `start`), deleted or not.
    private static func itemCount(around start: Date) async throws -> Int {
        try await Database.pool.read { db in
            try TimelineItemBase
                .filter(TimelineItemBase.Columns.startDate >= start.addingTimeInterval(-86_400))
                .filter(TimelineItemBase.Columns.startDate < start.addingTimeInterval(3 * 86_400))
                .fetchCount(db)
        }
    }
}
