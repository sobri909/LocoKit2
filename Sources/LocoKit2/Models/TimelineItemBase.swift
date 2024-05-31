//
//  TimelineItemBase.swift
//
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItemBase: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable {

    public var id: String = UUID().uuidString
    public let isVisit: Bool
    public let startDate: Date
    public let endDate: Date
    public var source: String = "LocoKit"
    public var samplesChanged = false
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

    // MARK: - Init

    init(from sample: inout LocomotionSample) {
        isVisit = sample.movingState == .stationary
        startDate = sample.date
        endDate = sample.date
        sample.timelineItemId = id
    }

}
