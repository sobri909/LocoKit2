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
    public let itemId: String
    public var distance: CLLocationDistance
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?

    public var id: String { itemId }

    public mutating func update(from samples: [LocomotionSample]) -> Bool {
        let oldSelf = self
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
        return !self.databaseEquals(oldSelf)
    }

    init(itemId: String, samples: [LocomotionSample]) {
        self.itemId = itemId
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
    }
}
