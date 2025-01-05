//
//  TimelineItemTrip.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItemTrip: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public static let minimumValidDuration: TimeInterval = 10
    public static let minimumValidDistance: Double = 10
    public static let minimumValidSamples = 2

    public static let minimumKeeperDuration: TimeInterval = 60
    public static let minimumKeeperDistance: Double = 20

    public let itemId: String
    public var distance: CLLocationDistance
    public var speed: CLLocationSpeed
    public var classifiedActivityType: ActivityType?
    public var confirmedActivityType: ActivityType?
    public var uncertainActivityType = true
    public var id: String { itemId }

    public var activityType: ActivityType? { confirmedActivityType ?? classifiedActivityType }

    // MARK: - Init

    init(itemId: String, samples: [LocomotionSample]) {
        self.itemId = itemId
        let distance = Self.calculateDistance(from: samples)
        self.speed = Self.calculateSpeed(from: samples, distance: distance)
        self.distance = distance
        self.classifiedActivityType = Self.calculateModeActivityType(from: samples)
        self.confirmedActivityType = Self.calculateConfirmedActivityType(from: samples)
    }

    // MARK: - Updating

    public mutating func update(from samples: [LocomotionSample]) async {
        self.distance = Self.calculateDistance(from: samples)
        self.speed = Self.calculateSpeed(from: samples, distance: distance)
        self.classifiedActivityType = Self.calculateModeActivityType(from: samples)
        self.confirmedActivityType = Self.calculateConfirmedActivityType(from: samples)
    }

    public mutating func updateUncertainty(from results: ClassifierResults) {
        uncertainActivityType = results.bestMatch.score < 0.75
    }

    private static func calculateDistance(from samples: [LocomotionSample]) -> CLLocationDistance {
        return samples.usableLocations().distance() ?? 0
    }

    private static func calculateSpeed(from samples: [LocomotionSample], distance: Double) -> CLLocationSpeed {
        if samples.count == 1, let first = samples.first {
            return first.location?.speed ?? 0

        }

        if samples.count >= 2, let first = samples.first, let last = samples.last {
            let duration = last.date - first.date
            return duration > 0 ? distance / duration : 0
        }

        return 0
    }

    private static func calculateModeActivityType(from samples: [LocomotionSample]) -> ActivityType? {
        let activityTypes = samples.compactMap { $0.activityType }
        let movingActivityTypes = activityTypes.filter(\.isMovingType)

        // prefer mode moving type
        return movingActivityTypes.mode() ?? activityTypes.mode()
    }

    private static func calculateConfirmedActivityType(from samples: [LocomotionSample]) -> ActivityType? {
        let confirmedTypes = samples.compactMap { $0.confirmedActivityType }
        if confirmedTypes.isEmpty { return nil }

        let typeCount = confirmedTypes.reduce(into: [:]) { counts, type in
            counts[type, default: 0] += 1
        }

        if let (majorityType, count) = typeCount.max(by: { $0.value < $1.value }),
           Double(count) / Double(samples.count) > 0.5 {
            return majorityType
        }

        return nil
    }

}
