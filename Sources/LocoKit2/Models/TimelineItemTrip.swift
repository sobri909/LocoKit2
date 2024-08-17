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
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?
    public var id: String { itemId }

    public var activityType: String? { confirmedActivityType ?? classifiedActivityType }

    // TODO: would be good to keep modeActivityType and modeMovingActivityType
    // or perhaps make sure classifiedActivityType always has a relatively up to date value,
    // which would make modeActivityType unnecessary(?)
    // and store a separate movingClassifiedActivityType at the same time,
    // to make modeMovingActivityType also unnecessary

    public func distance(from otherItem: TimelineItem) -> CLLocationDistance? {
        // trip - trip
        if otherItem.isTrip, let otherTrip = otherItem.trip {
            return nil // TODO: -
        }

        // trip - visit
        if otherItem.isVisit, let otherVisit = otherItem.visit {
            return nil // TODO: -
        }

        return nil
    }

    // MARK: -

    public mutating func update(from samples: [LocomotionSample]) -> Bool {
        let oldSelf = self
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
        return !self.databaseEquals(oldSelf)
    }

    // MARK: - Init

    init(itemId: String, samples: [LocomotionSample]) {
        self.itemId = itemId
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
    }

}
