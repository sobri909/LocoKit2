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
}
