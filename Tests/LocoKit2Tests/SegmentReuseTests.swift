//
//  SegmentReuseTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-15
//
//  BIG-995: a TimelineSegment refetches its items whenever anything in its date range changes, and an
//  item none of whose stored parts changed keeps the samples it already has loaded (BIG-790). Until
//  BIG-995 that item was rebuilt around the kept samples, which collated its segments again into new
//  arrays: equal to the old ones in every value, sharing no storage with them. Comparing the old and
//  new item then walked every sample of every segment before answering "equal", and SwiftUI makes
//  that comparison for a view input holding the item, on the main thread.
//
//  The test stages two refetches through a real TimelineSegment: one that leaves a long visit
//  untouched, and one after a stored part of it changes. Its assertions are about values and shared
//  storage; the timings it prints are a reading for the ticket, not a pass criterion.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class SegmentReuseTests: XCTestCase {

    /// The app adds the observer in `TimelineRecorder.startup()`; no test here calls it.
    private static let observing: Void = {
        Database.pool.add(transactionObserver: TimelineObserver.highlander)
    }()

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
        _ = Self.observing
    }

    @MainActor
    func testRefetchKeepsAnUnchangedItemAndReloadsAChangedOne() async throws {
        let start = TimelineTestFixtures.freshWindow()
        let sampleCount = 4_000
        let here = CLLocationCoordinate2D(latitude: 13.7400, longitude: 100.5600)
        let smallStart = start.addingTimeInterval(8 * 3600)

        // a long visit (4,000 samples, 5 s apart) and a short one after it; both with the
        // samplesChanged flag cleared, as processing leaves an item it has finished with
        let (bigId, smallId) = try await Database.pool.write { db in
            let big = try Self.makeVisit(start: start, count: sampleCount, interval: 5, at: here, db: db)
            let small = try Self.makeVisit(start: smallStart, count: 5, interval: 60, at: here, db: db)
            for id in [big.id, small.id] {
                guard var base = try TimelineItemBase.fetchOne(db, key: id) else { throw TimelineError.itemNotFound }
                try base.updateChanges(db) { $0.samplesChanged = false }
            }
            return (big.id, small.id)
        }

        let segment = TimelineSegment(dateRange: DateInterval(start: start, duration: 86_400))

        try await Self.waitUntil("the segment's first load") {
            segment.timelineItems?.first { $0.id == bigId }?.samples?.count == sampleCount
                && segment.timelineItems?.first { $0.id == smallId }?.samples?.count == 5
        }
        let before = try XCTUnwrap(segment.timelineItems?.first { $0.id == bigId })

        // MARK: a refetch that leaves the long visit untouched

        // a sample arrives in the SHORT visit: the segment refetches its range, the short visit is
        // marked changed by the insert trigger, and the long one is untouched
        try await Database.pool.write { db in
            let date = smallStart.addingTimeInterval(5 * 60)
            let location = CLLocation(
                coordinate: here, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 0, timestamp: date
            )
            var sample = LocomotionSample(date: date, movingState: .stationary, recordingState: .recording, location: location)
            sample.timelineItemId = smallId
            try sample.insert(db)
        }

        try await Self.waitUntil("the refetch after the short visit's new sample") {
            segment.timelineItems?.first { $0.id == smallId }?.samples?.count == 6
        }
        let after = try XCTUnwrap(segment.timelineItems?.first { $0.id == bigId })

        // readings first, so a failing run still prints them
        let fresh = try await TimelineItem.fetchItem(itemId: bigId, includeSamples: true, includePlace: true)
        let unwrappedFresh = try XCTUnwrap(fresh)
        let samples = try XCTUnwrap(before.samples)
        let acrossRefetch = Self.cost { before == after }
        let againstFreshRead = Self.cost { before == unwrappedFresh }
        let collate = Self.cost { !TimelineItem.collateSegments(from: samples, disabled: false).isEmpty }
        let location = try XCTUnwrap(samples.first?.location)
        let twin = CLLocation(
            coordinate: location.coordinate, altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy,
            course: location.course, speed: location.speed, timestamp: location.timestamp
        )
        print("""
            BIG-995 reading (\(sampleCount) samples, \(before.segments?.count ?? -1) segment(s), median of 21):
            BIG-995   before == after (the same item across a refetch that left it unchanged): \
            \(acrossRefetch.result), \(String(format: "%.1f", acrossRefetch.microseconds)) µs
            BIG-995   before == a fresh read of the same rows: \
            \(againstFreshRead.result), \(String(format: "%.1f", againstFreshRead.microseconds)) µs
            BIG-995   two CLLocation objects built from the same values compare equal: \(location == twin)
            BIG-995   one collateSegments(from:) over the samples: \(String(format: "%.1f", collate.microseconds)) µs
            BIG-995   samples share storage across the refetch: \(Self.sameStorage(before.samples, after.samples)); \
            segments share storage: \(Self.sameStorage(before.segments, after.segments))
            """)

        // staging: the long visit's rows are as they were when it was first loaded
        let storedBase = try await Database.pool.read { try TimelineItemBase.fetchOne($0, key: bigId) }
        XCTAssertEqual(storedBase, before.base, "staging: the long visit's base row must be unchanged by the short visit's new sample")

        XCTAssertEqual(before, after, "an unchanged item must compare equal across the refetch")
        XCTAssertTrue(Self.sameStorage(before.samples, after.samples), "an unchanged item keeps its loaded samples (BIG-790)")
        XCTAssertTrue(
            Self.sameStorage(before.segments, after.segments),
            "an unchanged item keeps its loaded segments too (BIG-995): collated again they are new arrays, and every comparison of the two items walks all of them"
        )

        // MARK: a refetch after a stored part of the long visit changes

        // no sample is touched: only the visit row. The kept item must not survive this.
        try await Database.pool.write { db in
            guard var visit = try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == bigId).fetchOne(db) else {
                throw TimelineError.itemNotFound
            }
            try visit.updateChanges(db) { $0.customTitle = "BIG-995" }
        }

        try await Self.waitUntil("the refetch after the long visit's title change") {
            segment.timelineItems?.first { $0.id == bigId }?.visit?.customTitle == "BIG-995"
        }
        let retitled = try XCTUnwrap(segment.timelineItems?.first { $0.id == bigId })

        XCTAssertNotEqual(before, retitled, "an item with a changed stored part must not compare equal to the old one")
        XCTAssertEqual(retitled.samples?.count, sampleCount, "a changed item must have its samples loaded")
        XCTAssertFalse(Self.sameStorage(before.samples, retitled.samples), "a changed item gets newly read samples, not the kept ones")
        XCTAssertEqual(retitled.segments?.reduce(0) { $0 + $1.samples.count }, sampleCount, "a changed item's segments must be collated from its newly read samples")
    }

    // MARK: - Helpers

    /// A visit of `count` samples `interval` seconds apart. `TimelineTestFixtures.makeItem` is fixed at
    /// a minute apart, and 4,000 of those would not fit the segment's one-day range.
    private static func makeVisit(start: Date, count: Int, interval: TimeInterval, at coordinate: CLLocationCoordinate2D, db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for index in 0..<count {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 0, timestamp: start.addingTimeInterval(Double(index) * interval)
            )
            let sample = LocomotionSample(date: location.timestamp, movingState: .stationary, recordingState: .recording, location: location)
            try sample.insert(db)
            samples.append(sample)
        }
        return try TimelineItem.createItem(from: samples, isVisit: true, db: db)
    }

    /// Whether two arrays of the same length are one buffer. Array's `==` answers at once for these and
    /// walks the elements otherwise (the standard library's behaviour, not a documented promise).
    /// Only meaningful for equal counts: arrays of different lengths are never one buffer.
    private static func sameStorage<T>(_ lhs: [T]?, _ rhs: [T]?) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, lhs.count == rhs.count else { return false }
        return lhs.withUnsafeBufferPointer { left in
            rhs.withUnsafeBufferPointer { right in left.baseAddress == right.baseAddress }
        }
    }

    /// The median of 21 runs, in microseconds, with the last result.
    private static func cost(_ body: () -> Bool) -> (result: Bool, microseconds: Double) {
        let clock = ContinuousClock()
        var result = false
        var times: [Duration] = []
        for _ in 0..<21 {
            times.append(clock.measure { result = body() })
        }
        times.sort()
        let median = times[10].components
        return (result, Double(median.seconds) * 1_000_000 + Double(median.attoseconds) / 1_000_000_000_000)
    }

    @MainActor
    private static func waitUntil(_ what: String, timeout: TimeInterval = 60, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !condition() {
            if Date.now > deadline {
                XCTFail("timed out waiting for \(what)")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
