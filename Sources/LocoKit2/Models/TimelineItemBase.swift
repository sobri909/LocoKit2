//
//  TimelineItemBase.swift
//
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class TimelineItemBase: Record, Identifiable, Codable {

    public var id: String = UUID().uuidString
    public let isVisit: Bool
    public let startDate: Date
    public let endDate: Date
    public var source: String = "LocoKit"
    public var deleted = false

    // extended
    public var stepCount: Int?
    public var floorsAscended: Int?
    public var floorsDescended: Int?
    public var averageAltitude: CLLocationDistance?
    public var activeEnergyBurned: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?

    public var dateRange: DateInterval {
        return DateInterval(start: startDate, end: endDate)
    }

    public var previousItemId: String? {
        didSet {
            // TODO: move these to SQL constraints?
            if previousItemId == id { fatalError("Can't link to self") }
            if previousItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public var nextItemId: String? {
        didSet {
            // TODO: move these to SQL constraints?
            if nextItemId == id { fatalError("Can't link to self") }
            if nextItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public static let visit = hasOne(TimelineItemVisit.self).forKey("visit")
    public static let trip = hasOne(TimelineItemTrip.self).forKey("trip")
    public static let samples = hasMany(LocomotionSample.self).forKey("samples")

    public var samples: QueryInterfaceRequest<LocomotionSample> {
        request(for: TimelineItemBase.samples)
    }

    public override class var databaseTableName: String { return "TimelineItemBase" }

    // MARK: - Init

    init(from sample: LocomotionSample) {
        isVisit = sample.movingState == .stationary
        startDate = sample.date
        endDate = sample.date
        super.init()
    }
    
    // MARK: - Record

    required init(row: Row) throws {
        id = row["id"]
        source = row["source"]
        isVisit = row["isVisit"]
        startDate = row["startDate"]
        endDate = row["endDate"]
        deleted = row["deleted"]

        previousItemId = row["previousItemId"]
        nextItemId = row["nextItemId"]

        stepCount = row["stepCount"]
        floorsAscended = row["floorsAscended"]
        floorsDescended = row["floorsDescended"]
        averageAltitude = row["averageAltitude"]
        activeEnergyBurned = row["activeEnergyBurned"]
        averageHeartRate = row["averageHeartRate"]
        maxHeartRate = row["maxHeartRate"]

        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source"] = source
        container["isVisit"] = isVisit
        container["startDate"] = startDate
        container["endDate"] = endDate
        container["deleted"] = deleted

        container["previousItemId"] = previousItemId
        container["nextItemId"] = nextItemId

        container["stepCount"] = stepCount
        container["floorsAscended"] = floorsAscended
        container["floorsDescended"] = floorsDescended
        container["averageAltitude"] = averageAltitude
        container["activeEnergyBurned"] = activeEnergyBurned
        container["averageHeartRate"] = averageHeartRate
        container["maxHeartRate"] = maxHeartRate
    }

}
