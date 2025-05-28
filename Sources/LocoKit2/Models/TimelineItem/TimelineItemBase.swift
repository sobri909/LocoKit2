//
//  TimelineItemBase.swift
//
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItemBase: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public var id: String = UUID().uuidString
    public var lastSaved: Date = .now
    public let isVisit: Bool
    public let startDate: Date?
    public let endDate: Date?
    public var source: String = "LocoKit2"
    public var sourceVersion: String = LocomotionManager.locoKitVersion
    public var disabled = false
    public var deleted = false

    public var samplesChanged = false

    // extended
    public var stepCount: Int?
    public var floorsAscended: Int?
    public var floorsDescended: Int?
    public var averageAltitude: CLLocationDistance?
    public var activeEnergyBurned: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?

    public var dateRange: DateInterval? {
        if let startDate, let endDate {
            return DateInterval(start: startDate, end: endDate)
        }
        return nil
    }

    public var previousItemId: String? {
        didSet {
            // TODO: move this to SQL constraints
            if previousItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public var nextItemId: String? {
        didSet {
            // TODO: move this to SQL constraints
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

    init(isVisit: Bool) {
        self.isVisit = isVisit
        self.startDate = nil
        self.endDate = nil
    }

    init(from sample: LocomotionSample) {
        self.isVisit = sample.movingState == .stationary
        self.startDate = sample.date
        self.endDate = sample.date
    }

}
