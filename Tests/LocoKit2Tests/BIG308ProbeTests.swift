//
//  BIG308ProbeTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-06
//
//  BIG-308 probe requests from the architect (note implementer-2026-11-06-0141-from-architect.txt). Throwaway
//  readings, not regression tests: each test prints its readout and asserts only the staging. Run on
//  c8e97ef^ (= b955e66) and on c8e97ef. Items are built the recorder's way (created from ONE sample, the
//  rest attached by timelineItemId), samples unclassified unless the cell says otherwise, no fetchSamples.
//  The suite never runs TimelineItemObserver, so these record FIRST decisions, not cascade counts.

import XCTest
import CoreLocation
import GRDB
@testable import LocoKit2

final class BIG308ProbeTests: XCTestCase {

    override func setUp() async throws {
        _ = TimelineTestFixtures.migrated
    }

    // MARK: - Probe A: siso's shape (BIG-625)

    /// keeper Home visit | trip1 ~13 min / 11 km | 37 s station visit | trip2 ~16 min / 11 km back | arrival at Home.
    /// Both Home visits on the same confirmed place. processFrom the arrival visit, as the recorder does at sleep.
    func testProbeA_sisoShape() async throws {
        let base = TimelineTestFixtures.freshWindow()
        let lat = 13.75
        let lonHome = 100.55
        let lonStation = lonHome + 0.1017            // ~11 km east at this latitude
        let edge = 0.00055                            // ~60 m
        let home = CLLocationCoordinate2D(latitude: lat, longitude: lonHome)
        let station = CLLocationCoordinate2D(latitude: lat, longitude: lonStation)

        let ids: (home: String, trip1: String, station: String, trip2: String, arrival: String, place: String) = try await Database.pool.write { db in
            var place = Place(coordinate: home, name: "Probe Home")
            try place.insert(db)

            let homeVisit = try Self.makeRecorderVisit(start: base, count: 15, interval: 60, at: home, jitterMetres: 0, db: db)
            try Self.confirm(place: place, on: homeVisit, db: db)

            let t1Start = base.addingTimeInterval(15 * 60)
            let t1Points = Self.line(from: lonHome + edge, to: lonStation - edge, lat: lat, count: 40)   // 40 × 20 s = 13 min
            let trip1 = try Self.makeRecorderTrip(start: t1Start, interval: 20, points: t1Points, speed: 14, db: db)

            let stStart = t1Start.addingTimeInterval(40 * 20)
            let stationVisit = try Self.makeRecorderVisit(start: stStart, count: 3, interval: 18.5, at: station, jitterMetres: 0, db: db)

            let t2Start = stStart.addingTimeInterval(37 + 20)
            let t2Points = Self.line(from: lonStation - edge, to: lonHome + edge, lat: lat, count: 48)  // 48 × 20 s = 16 min
            let trip2 = try Self.makeRecorderTrip(start: t2Start, interval: 20, points: t2Points, speed: 11.5, db: db)

            let arrStart = t2Start.addingTimeInterval(48 * 20)
            let arrival = try Self.makeRecorderVisit(start: arrStart, count: 15, interval: 60, at: home, jitterMetres: 0, db: db)
            try Self.confirm(place: place, on: arrival, db: db)

            try TimelineTestFixtures.link(db, homeVisit.id, trip1.id, stationVisit.id, trip2.id, arrival.id)
            return (homeVisit.id, trip1.id, stationVisit.id, trip2.id, arrival.id, place.id)
        }

        // staging receipts: the trips are stale with stored distance 0, the visits are on the confirmed place
        let (d1, d2, s1, homeRow, arr) = try await Database.pool.read { db in
            (try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == ids.trip1).fetchOne(db)?.distance,
             try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == ids.trip2).fetchOne(db)?.distance,
             try TimelineItemBase.fetchOne(db, key: ids.trip1)?.samplesChanged,
             try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == ids.home).fetchOne(db),
             try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == ids.arrival).fetchOne(db))
        }
        XCTAssertEqual(d1, 0, "staging: trip1 stored distance must be the one-sample 0")
        XCTAssertEqual(d2, 0, "staging: trip2 stored distance must be the one-sample 0")
        XCTAssertEqual(s1, true, "staging: trip1 must be flagged samplesChanged")
        XCTAssertEqual(homeRow?.placeId, ids.place); XCTAssertEqual(homeRow?.confirmedPlace, true)
        XCTAssertEqual(arr?.placeId, ids.place); XCTAssertEqual(arr?.confirmedPlace, true)

        Log.info("PROBE-A start home=\(ids.home.prefix(8)) trip1=\(ids.trip1.prefix(8)) station=\(ids.station.prefix(8)) trip2=\(ids.trip2.prefix(8)) arrival=\(ids.arrival.prefix(8))", subsystem: .timeline)
        try await Self.runProcessFrom(itemId: ids.arrival)
        Log.info("PROBE-A end", subsystem: .timeline)

        var out = "\n===== PROBE A readout (\(Self.build)) =====\n"
        for (name, id) in [("home", ids.home), ("trip1", ids.trip1), ("station", ids.station), ("trip2", ids.trip2), ("arrival", ids.arrival)] {
            out += try await Self.describe(name: name, id: id)
        }
        out += try await Self.holders(of: [("trip1", ids.trip1), ("trip2", ids.trip2), ("station", ids.station)], ids: ids)
        out += Self.logLines(between: "PROBE-A start", and: "PROBE-A end")
        print(out)
    }

    // MARK: - Probe B: the pull path, unclassified vs classified head

    /// As specified: a recorder-built visit of 21 samples clustered within ~3 m, then a recorder-built trip whose
    /// first 10 samples sit stationary 15 m from the cluster; one processFrom. The visit's 3 m cluster bounds
    /// its radius to the 10 m minimum, so this cell is also a read of the clamp.
    func testProbeB1_unclassified_3mCluster_head15m() async throws { try await Self.probeB(cell: "B1 unclassified, 3 m cluster, head 15 m", clusterMetres: 3, headMetres: 15, headType: nil) }
    func testProbeB1_stationary_3mCluster_head15m() async throws { try await Self.probeB(cell: "B1 stationary, 3 m cluster, head 15 m", clusterMetres: 3, headMetres: 15, headType: .stationary) }

    /// Implementer's addition: a visit wide enough (samples within ~12 m) that sd:1 and sd:2 land on different sides
    /// of a 15 m head once the radius is real, so the type's effect on the pull is visible on the refreshed build.
    func testProbeB2_unclassified_12mCluster_head15m() async throws { try await Self.probeB(cell: "B2 unclassified, 12 m cluster, head 15 m", clusterMetres: 12, headMetres: 15, headType: nil) }
    func testProbeB2_stationary_12mCluster_head15m() async throws { try await Self.probeB(cell: "B2 stationary, 12 m cluster, head 15 m", clusterMetres: 12, headMetres: 15, headType: .stationary) }

    /// Implementer's addition: samples at varying distances (0, 3, 6, 9, 12 m from the centre, repeating), so the
    /// refreshed visit's radius has a real spread (mean clamped to 10 m, sd ≈ 4 m): sd:1 ≈ 14 m, sd:2 ≈ 18 m, which
    /// puts a 15 m head outside at sd:1 and inside at sd:2, the discriminating cell for the type's effect.
    func testProbeB3_unclassified_spreadCluster_head15m() async throws { try await Self.probeB(cell: "B3 unclassified, spread 0-12 m cluster, head 15 m", clusterMetres: 12, headMetres: 15, headType: nil, spread: true) }
    func testProbeB3_stationary_spreadCluster_head15m() async throws { try await Self.probeB(cell: "B3 stationary, spread 0-12 m cluster, head 15 m", clusterMetres: 12, headMetres: 15, headType: .stationary, spread: true) }

    private static func probeB(cell: String, clusterMetres: Double, headMetres: Double, headType: ActivityType?, spread: Bool = false) async throws {
        let base = TimelineTestFixtures.freshWindow()
        let lat = 13.75, lon = 100.55
        let centre = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let metresPerDegLon = 111_320 * cos(lat * .pi / 180)
        let headLon = lon + headMetres / metresPerDegLon

        let (visitId, tripId, firstTripSampleId, headSampleIds): (String, String, String, [String]) = try await Database.pool.write { db in
            let visit = try makeRecorderVisit(start: base, count: 21, interval: 60, at: centre, jitterMetres: spread ? clusterMetres : clusterMetres / 2, spread: spread, db: db)
            let tripStart = base.addingTimeInterval(21 * 60)
            // 10 head samples sitting at the head point, then 20 samples moving away east at 5 m/s
            var points: [CLLocationCoordinate2D] = Array(repeating: CLLocationCoordinate2D(latitude: lat, longitude: headLon), count: 10)
            points += (1...20).map { CLLocationCoordinate2D(latitude: lat, longitude: headLon + Double($0) * 100 / metresPerDegLon) }
            let trip = try makeRecorderTrip(start: tripStart, interval: 20, points: points, speed: 5, headCount: 10, headType: headType, db: db)
            try TimelineTestFixtures.link(db, visit.id, trip.id)
            let samples = try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == trip.id).order(LocomotionSample.Columns.date).fetchAll(db)
            return (visit.id, trip.id, samples[0].id, samples.prefix(10).map(\.id))
        }

        let (visitRow, head) = try await Database.pool.read { db in
            (try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == visitId).fetchOne(db),
             try LocomotionSample.fetchOne(db, key: firstTripSampleId))
        }
        XCTAssertEqual(visitRow?.radiusMean, TimelineItemVisit.minRadius, "staging: a one-sample visit carries the minimum radius")
        XCTAssertEqual(head?.classifiedActivityType, headType, "staging: the head's classified type is the cell's")

        Log.info("PROBE-B start [\(cell)] visit=\(visitId.prefix(8)) trip=\(tripId.prefix(8))", subsystem: .timeline)
        try await Self.runProcessFrom(itemId: tripId)
        Log.info("PROBE-B end [\(cell)]", subsystem: .timeline)

        let (afterVisit, headHolders, tripCount, visitCount) = try await Database.pool.read { db in
            (try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == visitId).fetchOne(db),
             try headSampleIds.map { try LocomotionSample.fetchOne(db, key: $0)?.timelineItemId == visitId },
             try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == tripId).fetchCount(db),
             try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == visitId).fetchCount(db))
        }
        var out = "\n===== PROBE B readout (\(Self.build)) [\(cell)] =====\n"
        out += "first trip sample moved into the visit: \(headHolders.first ?? false); head samples now in the visit: \(headHolders.filter { $0 }.count)/10\n"
        out += "visit samples after: \(visitCount) (staged 21); trip samples after: \(tripCount) (staged 30)\n"
        out += "visit row after: radiusMean=\(afterVisit?.radiusMean ?? -1) radiusSD=\(afterVisit?.radiusSD ?? -1) center=\(afterVisit?.latitude ?? -1),\(afterVisit?.longitude ?? -1)\n"
        out += Self.logLines(between: "PROBE-B start [\(cell)]", and: "PROBE-B end [\(cell)]")
        print(out)
    }

    // MARK: - Staging helpers

    static var build: String {
        // the TEMP marker file is written by the run script so the readout names the commit
        (try? String(contentsOfFile: "/tmp/308-build.txt", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown build"
    }

    /// The recorder's way for a visit: created from the first stationary sample, the rest attached by
    /// timelineItemId, no updateFrom. `jitterMetres` spreads the samples deterministically around `at`.
    static func makeRecorderVisit(start: Date, count: Int, interval: TimeInterval, at coordinate: CLLocationCoordinate2D, jitterMetres: Double, spread: Bool = false, db: GRDB.Database) throws -> TimelineItem {
        let metresPerDegLat = 111_320.0
        let metresPerDegLon = 111_320 * cos(coordinate.latitude * .pi / 180)
        var samples: [LocomotionSample] = []
        for index in 0..<count {
            // a fixed 8-point ring plus the centre, so the spread is reproducible
            let angle = Double(index % 8) * .pi / 4
            let r = index == 0 ? 0 : (spread ? jitterMetres * Double(index % 5) / 4 : jitterMetres)
            let c = CLLocationCoordinate2D(latitude: coordinate.latitude + r * sin(angle) / metresPerDegLat,
                                           longitude: coordinate.longitude + r * cos(angle) / metresPerDegLon)
            let location = CLLocation(coordinate: c, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                                      course: 0, speed: 0, timestamp: start.addingTimeInterval(Double(index) * interval))
            let sample = LocomotionSample(date: location.timestamp, movingState: .stationary, recordingState: .recording, location: location)
            try sample.insert(db)
            samples.append(sample)
        }
        let item = try TimelineItem.createItem(from: [samples[0]], isVisit: true, db: db)
        for var sample in samples.dropFirst() {
            try sample.updateChanges(db) { $0.timelineItemId = item.id }
        }
        return item
    }

    /// The recorder's way for a trip (as StaleTripProcessingTests.makeRecorderTrip), with an optional head: the
    /// first `headCount` samples carry movingState .uncertain, speed 0 and `headType` as their classified type.
    static func makeRecorderTrip(start: Date, interval: TimeInterval, points: [CLLocationCoordinate2D], speed: Double,
                                 headCount: Int = 0, headType: ActivityType? = nil, db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for (index, coordinate) in points.enumerated() {
            let isHead = index < headCount
            let location = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                                      course: 90, speed: isHead ? 0 : speed, timestamp: start.addingTimeInterval(Double(index) * interval))
            var sample = LocomotionSample(date: location.timestamp, movingState: isHead ? .uncertain : .moving, recordingState: .recording, location: location)
            if isHead { sample.classifiedActivityType = headType }
            try sample.insert(db)
            samples.append(sample)
        }
        let item = try TimelineItem.createItem(from: [samples[0]], isVisit: false, db: db)
        for var sample in samples.dropFirst() {
            try sample.updateChanges(db) { $0.timelineItemId = item.id }
        }
        return item
    }

    static func confirm(place: Place, on item: TimelineItem, db: GRDB.Database) throws {
        guard var visit = try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == item.id).fetchOne(db) else { throw TimelineError.itemNotFound }
        try visit.updateChanges(db) { $0.placeId = place.id; $0.confirmedPlace = true; $0.uncertainPlace = false }
    }

    static func line(from lonA: Double, to lonB: Double, lat: Double, count: Int) -> [CLLocationCoordinate2D] {
        (0..<count).map { CLLocationCoordinate2D(latitude: lat, longitude: lonA + Double($0) / Double(count - 1) * (lonB - lonA)) }
    }

    // MARK: - Running and reading out

    static func runProcessFrom(itemId: String, timeout: TimeInterval = 120) async throws {
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

    static func describe(name: String, id: String) async throws -> String {
        try await Database.pool.read { db in
            let base = try TimelineItemBase.fetchOne(db, key: id)
            let count = try LocomotionSample.filter(LocomotionSample.Columns.timelineItemId == id).fetchCount(db)
            let trip = try TimelineItemTrip.filter(TimelineItemTrip.Columns.itemId == id).fetchOne(db)
            let visit = try TimelineItemVisit.filter(TimelineItemVisit.Columns.itemId == id).fetchOne(db)
            var s = "\(name) \(id.prefix(8)): deleted=\(base?.deleted ?? true) samples=\(count) samplesChanged=\(base?.samplesChanged ?? false) prev=\(base?.previousItemId?.prefix(8) ?? "nil") next=\(base?.nextItemId?.prefix(8) ?? "nil")"
            if let trip { s += " trip.distance=\(Int(trip.distance))" }
            if let visit { s += " visit.radiusMean=\(visit.radiusMean) placeId=\(visit.placeId?.prefix(8) ?? "nil") confirmed=\(visit.confirmedPlace)" }
            return s + "\n"
        }
    }

    /// Where each staged item's samples ended up, by the item that holds them now.
    static func holders(of items: [(String, String)], ids: (home: String, trip1: String, station: String, trip2: String, arrival: String, place: String)) async throws -> String {
        let names = [ids.home: "home", ids.trip1: "trip1", ids.station: "station", ids.trip2: "trip2", ids.arrival: "arrival"]
        _ = items
        let holderIds = Array(names.keys)
        return try await Database.pool.read { db in
            var s = ""
            // every sample still held by one of the five staged items, grouped by its holder
            let all = try LocomotionSample.filter(holderIds.contains(LocomotionSample.Columns.timelineItemId)).fetchAll(db)
            let grouped = Dictionary(grouping: all, by: { $0.timelineItemId ?? "nil" })
            for (holder, samples) in grouped.sorted(by: { $0.value.first!.date < $1.value.first!.date }) {
                s += "holder \(names[holder] ?? holder.prefix(8).description): \(samples.count) samples, \(samples.min(by: { $0.date < $1.date })!.date) → \(samples.max(by: { $0.date < $1.date })!.date)\n"
            }
            return s
        }
    }

    /// Lines the file logger wrote between two markers (the newest log in Documents/Logs).
    static func logLines(between start: String, and end: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logs = docs.appendingPathComponent("Logs")
        guard let files = try? FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: [.contentModificationDateKey]),
              let newest = files.filter({ $0.pathExtension == "log" }).max(by: { (a, b) in
                  ((try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                  < ((try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }),
              let text = try? String(contentsOf: newest, encoding: .utf8) else { return "(no log file found under \(logs.path))\n" }
        let lines = text.components(separatedBy: "\n")
        guard let s = lines.lastIndex(where: { $0.contains(start) }) else { return "(start marker not found in \(newest.lastPathComponent))\n" }
        let e = lines[s...].firstIndex(where: { $0.contains(end) }) ?? lines.endIndex - 1
        let wanted = lines[s...e].filter { $0.contains("merge") || $0.contains("Merge") || $0.contains("PROBE") || $0.contains("refreshed on load") || $0.contains("steal") || $0.contains("heal") }
        return "--- log (\(newest.lastPathComponent)), \(e - s) lines between markers, \(wanted.count) shown:\n" + wanted.joined(separator: "\n") + "\n"
    }
}
