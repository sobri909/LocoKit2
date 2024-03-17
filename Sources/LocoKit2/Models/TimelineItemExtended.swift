//
//  TimelineItemExtended.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItemExtended: Codable, FetchableRecord, PersistableRecord {
    public let itemId: String
    public var stepCount: Int?
    public var floorsAscended: Int?
    public var floorsDescended: Int?
    public var averageAltitude: CLLocationDistance?
    public var activeEnergyBurned: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
}
