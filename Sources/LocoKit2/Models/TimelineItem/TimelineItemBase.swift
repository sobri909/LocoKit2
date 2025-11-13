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
    public var locked = false

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
            if previousItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public var nextItemId: String? {
        didSet {
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

    // MARK: - Columns

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let lastSaved = Column(CodingKeys.lastSaved)
        public static let isVisit = Column(CodingKeys.isVisit)
        public static let startDate = Column(CodingKeys.startDate)
        public static let endDate = Column(CodingKeys.endDate)
        public static let source = Column(CodingKeys.source)
        public static let sourceVersion = Column(CodingKeys.sourceVersion)
        public static let disabled = Column(CodingKeys.disabled)
        public static let deleted = Column(CodingKeys.deleted)
        public static let locked = Column(CodingKeys.locked)
        public static let samplesChanged = Column(CodingKeys.samplesChanged)
        public static let stepCount = Column(CodingKeys.stepCount)
        public static let floorsAscended = Column(CodingKeys.floorsAscended)
        public static let floorsDescended = Column(CodingKeys.floorsDescended)
        public static let averageAltitude = Column(CodingKeys.averageAltitude)
        public static let activeEnergyBurned = Column(CodingKeys.activeEnergyBurned)
        public static let averageHeartRate = Column(CodingKeys.averageHeartRate)
        public static let maxHeartRate = Column(CodingKeys.maxHeartRate)
        public static let previousItemId = Column(CodingKeys.previousItemId)
        public static let nextItemId = Column(CodingKeys.nextItemId)
    }
    
}
