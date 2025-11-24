//
//  LegacyItem.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import GRDB

public struct LegacyItem: FetchableRecord, TableRecord, Codable, Hashable, Sendable, Identifiable {
    public static var databaseTableName: String { return "TimelineItem" }

    public var id: String { itemId }
    public var itemId: String
    public let isVisit: Bool
    public let startDate: Date?
    public let endDate: Date?
    public var source: String = "LocoKit"
    public var deleted = false
    public var disabled = false
    
    // Visit specific fields
    public var placeId: String?
    public var manualPlace: Bool?
    public var streetAddress: String?
    public var customTitle: String?
    
    // Path specific fields
    public var distance: Double?
    public var manualActivityType: Bool?
    public var activityType: String?
    public var activityTypeConfidenceScore: Double?
    
    // Health-related fields
    public var activeEnergyBurned: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var hkStepCount: Double?  // "hk" prefix might be needed to match old schema

    public var dateRange: DateInterval? {
        guard let startDate, let endDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }

    public var previousItemId: String?
    public var nextItemId: String?

    // MARK: - Initializers
    
    // Used for TimelineRecorder
    public init(from sample: LegacySample) {
        self.itemId = UUID().uuidString
        self.isVisit = sample.movingState == "stationary"
        self.startDate = sample.date
        self.endDate = sample.date
        self.source = sample.source
    }

    // MARK: - Columns

    public enum Columns {
        public static let itemId = Column("itemId")
        public static let isVisit = Column("isVisit")
        public static let startDate = Column("startDate")
        public static let endDate = Column("endDate")
        public static let source = Column("source")
        public static let deleted = Column("deleted")
        public static let disabled = Column("disabled")
        public static let placeId = Column("placeId")
        public static let manualPlace = Column("manualPlace")
        public static let streetAddress = Column("streetAddress")
        public static let customTitle = Column("customTitle")
        public static let distance = Column("distance")
        public static let manualActivityType = Column("manualActivityType")
        public static let activityType = Column("activityType")
        public static let activityTypeConfidenceScore = Column("activityTypeConfidenceScore")
        public static let activeEnergyBurned = Column("activeEnergyBurned")
        public static let averageHeartRate = Column("averageHeartRate")
        public static let maxHeartRate = Column("maxHeartRate")
        public static let hkStepCount = Column("hkStepCount")
        public static let previousItemId = Column("previousItemId")
        public static let nextItemId = Column("nextItemId")
    }
}
