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
    public var distance: CLLocationDistance
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?

    public override class var databaseTableName: String { return "TimelineItemTrip" }

    // MARK: -
    
    public func update(from samples: [LocomotionSample]) {
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
    }

    // MARK: - Init

    init?(itemId: String, samples: [LocomotionSample]) {
        self.itemId = itemId
        self.distance = samples.compactMap { $0.location }.usableLocations().distance() ?? 0
        super.init()
    }

    // MARK: - Record

    required init(row: Row) throws {
        itemId = row["itemId"]
        distance = row["distance"]
        classifiedActivityType = row["classifiedActivityType"]
        confirmedActivityType = row["confirmedActivityType"]
        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["itemId"] = itemId
        container["distance"] = distance
        container["classifiedActivityType"] = classifiedActivityType
        container["confirmedActivityType"] = confirmedActivityType
    }
}
