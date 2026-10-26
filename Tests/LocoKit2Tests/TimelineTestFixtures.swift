//
//  TimelineTestFixtures.swift
//  LocoKit2
//
//  Created by Claude on 2026-10-26
//
//  Builders shared by the timeline tests: a time window of its own per test, items with real samples,
//  and next-edge chaining. Moved out of MergeLoopTests (BIG-752) when BIG-908's tests needed them.

import Foundation
import CoreLocation
import GRDB
@testable import LocoKit2

enum TimelineTestFixtures {

    /// Migrations run once per test process. Each class holding its own copy registered them twice when
    /// two classes ran together, and GRDB stops on "already registered migration".
    static let migrated: Void = {
        Database.highlander.doMigrations()
    }()

    /// The test host's database persists across runs, and edge healing searches a day either side of an
    /// item, so every test gets a window of its own: a random three-day slot between 1980 and 2062.
    static func freshWindow() -> Date {
        let slot = Double(Int.random(in: 0..<10_000))
        return Date(timeIntervalSince1970: 315_532_800 + slot * 3 * 86_400)
    }

    /// An item of `count` samples a minute apart at `coordinate`, inserted with its samples.
    static func makeItem(isVisit: Bool, start: Date, count: Int, at coordinate: CLLocationCoordinate2D, locked: Bool = false, db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for index in 0..<count {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: isVisit ? 0 : 5, timestamp: start.addingTimeInterval(Double(index) * 60)
            )
            let sample = LocomotionSample(
                date: location.timestamp,
                movingState: isVisit ? .stationary : .moving,
                recordingState: .recording,
                location: location
            )
            try sample.insert(db)
            samples.append(sample)
        }
        return try TimelineItem.createItem(from: samples, isVisit: isVisit, locked: locked, db: db)
    }

    /// A moving trip through `points`, one sample per point `interval` apart, with a confirmed type if
    /// given. Unlike `makeItem`'s single-coordinate trips it has a real distance, so it can be valid
    /// or a keeper and is scored as one.
    static func makeTrip(start: Date, interval: TimeInterval, points: [CLLocationCoordinate2D], type: ActivityType?, locked: Bool = false, db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for (index, coordinate) in points.enumerated() {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 5, timestamp: start.addingTimeInterval(Double(index) * interval)
            )
            let sample = LocomotionSample(date: location.timestamp, movingState: .moving, recordingState: .recording, location: location)
            try sample.insert(db)
            samples.append(sample)
        }
        var item = try TimelineItem.createItem(from: samples, isVisit: false, locked: locked, db: db)
        if let type {
            try item.trip?.updateChanges(db) {
                $0.confirmedActivityType = type
                $0.uncertainActivityType = false
            }
        }
        return item
    }

    /// A data gap: two recording-off samples at `coordinate`, `duration` apart.
    static func makeDataGap(start: Date, duration: TimeInterval, at coordinate: CLLocationCoordinate2D, db: GRDB.Database) throws -> TimelineItem {
        var samples: [LocomotionSample] = []
        for date in [start, start.addingTimeInterval(duration)] {
            let location = CLLocation(
                coordinate: coordinate, altitude: 10, horizontalAccuracy: 10, verticalAccuracy: 10,
                course: 0, speed: 0, timestamp: date
            )
            let sample = LocomotionSample(date: date, movingState: .stationary, recordingState: .off, location: location)
            try sample.insert(db)
            samples.append(sample)
        }
        return try TimelineItem.createItem(from: samples, isVisit: false, db: db)
    }

    /// Chains items by their next edges; the AFTER UPDATE triggers set the matching previous edges.
    static func link(_ db: GRDB.Database, _ ids: String...) throws {
        for (current, next) in zip(ids, ids.dropFirst()) {
            guard var base = try TimelineItemBase.fetchOne(db, key: current) else { throw TimelineError.itemNotFound }
            try base.updateChanges(db) { $0.nextItemId = next }
        }
    }
}
