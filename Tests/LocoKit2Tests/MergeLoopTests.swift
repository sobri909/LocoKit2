//
//  MergeLoopTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-10-23
//
//  BIG-752: TimelineProcessor.process() must never retry a merge that cannot apply against the same
//  cached list forever. Two shapes from the 13 Pro storms (4,587 identical merge lines in 33 s):
//  a merge inheriting an edge that points at a deleted item, and an item carrying such an edge that
//  nothing repaired. These run against the real schema and triggers on the simulator's test host.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class MergeLoopTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    // MARK: - Case B: the deadman's edge points at a deleted item in the database

    /// K (a keeper visit) <- I (a one-sample item whose previousItemId names a deleted item). Before
    /// the fix the keeper inherited that edge, the BEFORE UPDATE trigger refused the write, and the
    /// loop retried the same merge without limit. Now the inherited edge is read fresh and a dangling
    /// one is inherited as nil, so the merge applies and the loop ends.
    func testMergeInheritingADanglingEdgeAppliesAndTheLoopEnds() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let home = CLLocationCoordinate2D(latitude: 13.75, longitude: 100.55)

        let (deadId, keeperId, invalidId) = try await Self.stageDanglingPair(base: base, at: home)

        let edgeBefore = try await Database.pool.read { db in
            try TimelineItemBase.fetchOne(db, key: invalidId)?.previousItemId
        }
        XCTAssertEqual(edgeBefore, deadId, "staging: the invalid item's previous edge must name the deleted item")

        try await Self.runProcess(itemIds: [invalidId, keeperId])

        let (invalidDeleted, keeperPrevious, keeperDeleted) = try await Database.pool.read { db in
            (try TimelineItemBase.fetchOne(db, key: invalidId)?.deleted,
             try TimelineItemBase.fetchOne(db, key: keeperId)?.previousItemId,
             try TimelineItemBase.fetchOne(db, key: keeperId)?.deleted)
        }
        XCTAssertEqual(invalidDeleted, true, "the one-sample item should have been merged into the keeper")
        XCTAssertEqual(keeperDeleted, false)
        XCTAssertNotEqual(keeperPrevious, deadId, "the keeper must not inherit an edge to a deleted item")
        try await Self.assertNoLiveEdgeToADeletedItem(among: [invalidId, keeperId, deadId])
    }

    // MARK: - Case A: a chain whose middle items merge away, one after another

    /// V -> T -> I -> K. After V consumes T, the edge triggers rewire I's previous edge in the database
    /// while the loop's cache keeps I's old copy; K's merge of I used to inherit that stale edge and
    /// be refused forever. The loop must end with every edge pointing at a live item.
    func testChainOfMergesEndsWithNoEdgeToADeletedItem() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let home = CLLocationCoordinate2D(latitude: -8.65, longitude: 115.13)
        let away = CLLocationCoordinate2D(latitude: -8.70, longitude: 115.20)

        let ids = try await Database.pool.write { db -> [String] in
            let v = try TimelineTestFixtures.makeItem(isVisit: true, start: base, count: 12, at: home, db: db)
            let t = try TimelineTestFixtures.makeItem(isVisit: false, start: base.addingTimeInterval(13 * 60), count: 1, at: home, db: db)
            let i = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(15 * 60), count: 1, at: home, db: db)
            let k = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(17 * 60), count: 12, at: away, db: db)
            try TimelineTestFixtures.link(db, v.id, t.id, i.id, k.id)
            return [v.id, t.id, i.id, k.id]
        }

        try await Self.runProcess(itemIds: ids)

        let (v, t, i, k) = (ids[0], ids[1], ids[2], ids[3])
        let rows = try await Database.pool.read { db in
            try TimelineItemBase.filter(ids.contains(TimelineItemBase.Columns.id)).fetchAll(db)
        }
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        XCTAssertEqual(byId[t]?.deleted, true, "the one-sample trip should have merged away")
        XCTAssertEqual(byId[i]?.deleted, true, "the one-sample visit should have merged away")
        XCTAssertEqual(byId[v]?.deleted, false)
        XCTAssertEqual(byId[k]?.deleted, false)
        XCTAssertEqual(byId[v]?.nextItemId, k, "the two keepers should be neighbours once the middle is gone")
        XCTAssertEqual(byId[k]?.previousItemId, v)
        let sampleCount = try await Database.pool.read { db in
            try LocomotionSample.filter(ids.contains(LocomotionSample.Columns.timelineItemId)).fetchCount(db)
        }
        XCTAssertEqual(sampleCount, 26, "every sample should still belong to one of the four items")
        try await Self.assertNoLiveEdgeToADeletedItem(among: ids)
    }

    // MARK: - The merge itself, without the heal pass in front of it

    /// D(deleted) <- I -> K, merged directly: the keeper inherits nil for the dangling edge.
    func testMergeInheritsNilForADanglingEdge() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let home = CLLocationCoordinate2D(latitude: 1.29, longitude: 103.85)
        let (deadId, keeperId, invalidId) = try await Self.stageDanglingPair(base: base, at: home)

        let result = await Task { @TimelineActor () -> (merged: Bool, keeperPrevious: String??) in
            let list = await TimelineLinkedList(fromItemIds: [invalidId, keeperId])
            guard let keeper = await list.itemFor(itemId: keeperId), let deadman = await list.itemFor(itemId: invalidId) else {
                return (false, nil)
            }
            let merge = await Merge(keeper: keeper, deadman: deadman, in: list)
            if case .merged(let outcome) = await merge.doIt() {
                return (true, .some(outcome.kept.base.previousItemId))
            }
            return (false, nil)
        }.value
        XCTAssertTrue(result.merged, "the merge should apply; the dangling edge is inherited as nil")
        XCTAssertEqual(result.keeperPrevious, .some(nil), "the keeper must inherit nil, not the deleted id \(deadId.prefix(8))")

        let (invalidDeleted, keeperPrevious, keeperSamples) = try await Database.pool.read { db in
            (try TimelineItemBase.fetchOne(db, key: invalidId)?.deleted,
             try TimelineItemBase.fetchOne(db, key: keeperId)?.previousItemId,
             try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == keeperId).fetchCount(db))
        }
        XCTAssertEqual(invalidDeleted, true)
        XCTAssertNil(keeperPrevious)
        XCTAssertEqual(keeperSamples, 13, "the invalid item's sample should have moved to the keeper")
    }

    /// V -> T -> I -> K with the list's cache warm. V consumes T through the merge directly (the edge
    /// triggers set I.previous = V in the database) and I is NOT invalidated, as the loop used to leave
    /// it. K consuming the cached I used to inherit I's stale previous edge (T, now deleted) and be
    /// refused; the merge reads the edge fresh now and K.previous becomes V.
    func testMergeReadsTheInheritedEdgeFreshWhenTheCacheIsStale() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let home = CLLocationCoordinate2D(latitude: 48.86, longitude: 2.35)
        let away = CLLocationCoordinate2D(latitude: 48.90, longitude: 2.40)
        let ids = try await Database.pool.write { db -> [String] in
            let v = try TimelineTestFixtures.makeItem(isVisit: true, start: base, count: 12, at: home, db: db)
            let t = try TimelineTestFixtures.makeItem(isVisit: false, start: base.addingTimeInterval(13 * 60), count: 1, at: home, db: db)
            let i = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(15 * 60), count: 1, at: away, db: db)
            let k = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(17 * 60), count: 12, at: away, db: db)
            try TimelineTestFixtures.link(db, v.id, t.id, i.id, k.id)
            return [v.id, t.id, i.id, k.id]
        }
        let (v, t, i, k) = (ids[0], ids[1], ids[2], ids[3])

        let result = await Task { @TimelineActor () -> (first: Bool, second: Bool, keeperPrevious: String??) in
            let list = await TimelineLinkedList(fromItemIds: ids)
            // warm the cache for all four
            for id in ids { _ = await list.itemFor(itemId: id) }
            guard let vItem = await list.itemFor(itemId: v), let tItem = await list.itemFor(itemId: t),
                  let iItem = await list.itemFor(itemId: i), let kItem = await list.itemFor(itemId: k) else {
                return (false, false, nil)
            }
            guard case .merged = await Merge(keeper: vItem, deadman: tItem, in: list).doIt() else { return (false, false, nil) }
            // the loop's old behaviour: I stays cached with previous = T
            if case .merged(let outcome) = await Merge(keeper: kItem, deadman: iItem, in: list).doIt() {
                return (true, true, .some(outcome.kept.base.previousItemId))
            }
            return (true, false, nil)
        }.value
        XCTAssertTrue(result.first, "V <- T should apply")
        XCTAssertTrue(result.second, "K <- I should apply against the fresh row, not be refused for the stale cached edge")
        XCTAssertEqual(result.keeperPrevious, .some(v), "K should inherit I's CURRENT previous edge, V")

        let keeperPrevious = try await Database.pool.read { db in try TimelineItemBase.fetchOne(db, key: k)?.previousItemId }
        XCTAssertEqual(keeperPrevious, v)
        try await Self.assertNoLiveEdgeToADeletedItem(among: ids)
    }

    /// The write is the fresh row plus one edge: a column that moved in the database after the list
    /// cached the keeper (here stepCount, as the recording item's end date would) survives the merge.
    func testMergeDoesNotWriteStaleCachedColumnsBack() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let home = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.69)
        let (invalidId, keeperId) = try await Database.pool.write { db -> (String, String) in
            let invalid = try TimelineTestFixtures.makeItem(isVisit: true, start: base, count: 1, at: home, db: db)
            let keeper = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(120), count: 12, at: home, db: db)
            try TimelineTestFixtures.link(db, invalid.id, keeper.id)
            return (invalid.id, keeper.id)
        }

        let merged = await Task { @TimelineActor () -> Bool in
            let list = await TimelineLinkedList(fromItemIds: [invalidId, keeperId])
            guard let keeper = await list.itemFor(itemId: keeperId), let deadman = await list.itemFor(itemId: invalidId) else { return false }
            // the database moves on after the cache was warmed
            try? await Database.pool.write { db in
                try TimelineItemBase.filter(TimelineItemBase.Columns.id == keeperId)
                    .updateAll(db, TimelineItemBase.Columns.stepCount.set(to: 123))
            }
            if case .merged = await Merge(keeper: keeper, deadman: deadman, in: list).doIt() { return true }
            return false
        }.value
        XCTAssertTrue(merged)

        let stepCount = try await Database.pool.read { db in try TimelineItemBase.fetchOne(db, key: keeperId)?.stepCount }
        XCTAssertEqual(stepCount, 123, "the merge must not write the cached nil over a value the database gained since")
    }

    // MARK: - Healing: an edge to a deleted item is cleared, not left forever

    /// An item alone in its window whose previous edge names a deleted item. Nothing could merge it;
    /// before the fix nothing repaired it either (healing only ever filled nil edges).
    func testHealingClearsAnEdgeToADeletedItem() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let somewhere = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.69)

        let (itemId, deadId) = try await Database.pool.write { db -> (String, String) in
            let item = try TimelineTestFixtures.makeItem(isVisit: true, start: base, count: 12, at: somewhere, db: db)
            let deadId = UUID().uuidString
            var itemBase = item.base
            try itemBase.updateChanges(db) { $0.previousItemId = deadId }
            var dead = TimelineItemBase(isVisit: false)
            dead.id = deadId
            dead.deleted = true
            try dead.insert(db)
            return (item.id, deadId)
        }

        try await Self.runProcess(itemIds: [itemId])

        let previous = try await Database.pool.read { db in
            try TimelineItemBase.fetchOne(db, key: itemId)?.previousItemId
        }
        XCTAssertNil(previous, "the edge to the deleted item \(deadId.prefix(8)) should have been cleared")
    }

    // MARK: - Helpers

    /// I (one sample, previousItemId naming a deleted row D) -> K (twelve samples). Returns (D, K, I).
    private static func stageDanglingPair(base: Date, at coordinate: CLLocationCoordinate2D) async throws -> (String, String, String) {
        try await Database.pool.write { db -> (String, String, String) in
            // I first, naming D before D exists: the BEFORE INSERT trigger checks only against rows
            // that exist, and the deferred foreign key is satisfied once D is inserted below
            let invalid = try TimelineTestFixtures.makeItem(isVisit: true, start: base, count: 1, at: coordinate, db: db)
            let deadId = UUID().uuidString
            var invalidBase = invalid.base
            try invalidBase.updateChanges(db) { $0.previousItemId = deadId }
            var dead = TimelineItemBase(isVisit: true)
            dead.id = deadId
            dead.deleted = true
            try dead.insert(db)

            let keeper = try TimelineTestFixtures.makeItem(isVisit: true, start: base.addingTimeInterval(120), count: 12, at: coordinate, db: db)
            var keeperBase = keeper.base
            try keeperBase.updateChanges(db) { $0.previousItemId = invalid.id }
            return (deadId, keeper.id, invalid.id)
        }
    }

    /// Runs the processing loop under a timeout: a loop that never returns is the bug under test.
    private static func runProcess(itemIds: [String], timeout: TimeInterval = 60) async throws {
        let done = XCTestExpectation(description: "TimelineProcessor.process returned")
        let task = Task { @TimelineActor in
            let list = await TimelineLinkedList(fromItemIds: itemIds)
            await TimelineProcessor.process(list)
            done.fulfill()
        }
        let outcome = await XCTWaiter().fulfillment(of: [done], timeout: timeout)
        if outcome != .completed {
            task.cancel()
            XCTFail("TimelineProcessor.process did not return within \(Int(timeout)) s: the loop spun")
        }
    }

    /// The invariant both fixes protect: no live item's edge names a deleted item.
    private static func assertNoLiveEdgeToADeletedItem(among ids: [String], file: StaticString = #filePath, line: UInt = #line) async throws {
        let bad = try await Database.pool.read { db -> [String] in
            let rows = try TimelineItemBase
                .filter(ids.contains(TimelineItemBase.Columns.id))
                .filter(TimelineItemBase.Columns.deleted == false)
                .fetchAll(db)
            var bad: [String] = []
            for row in rows {
                for edge in [row.previousItemId, row.nextItemId].compactMap({ $0 }) {
                    let live = try TimelineItemBase
                        .filter(TimelineItemBase.Columns.id == edge)
                        .filter(TimelineItemBase.Columns.deleted == false)
                        .fetchCount(db) > 0
                    if !live { bad.append("\(row.id.prefix(8)) -> \(edge.prefix(8))") }
                }
            }
            return bad
        }
        XCTAssertTrue(bad.isEmpty, "live edges to deleted items: \(bad)", file: file, line: line)
    }
}
