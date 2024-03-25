//
//  TimelineItemTrip.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class TimelineItemTrip: Record, Codable {
    public let itemId: String
    public var isStale = false
    public var distance: CLLocationDistance
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?

    public override class var databaseTableName: String { return "TimelineItemTrip" }

    // MARK: -
    
    public func update(from samples: [LocomotionSample]) {
        self.isStale = false
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
    }

    // MARK: - Init

    init?(itemId: String, samples: [LocomotionSample]) {
        self.itemId = itemId
        self.isStale = false
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
        super.init()
    }

    // MARK: - Record

    required init(row: Row) throws {
        itemId = row["itemId"]
        isStale = row["isStale"]
        distance = row["distance"]
        classifiedActivityType = row["classifiedActivityType"]
        confirmedActivityType = row["confirmedActivityType"]
        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["itemId"] = itemId
        container["isStale"] = isStale
        container["distance"] = distance
        container["classifiedActivityType"] = classifiedActivityType
        container["confirmedActivityType"] = confirmedActivityType
    }
}
