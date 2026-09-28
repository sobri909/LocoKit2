//
//  LegacyBackup+Item.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyBackup {

    /// One `TimelineItem/<prefix>/<itemId>.json` file. Keys are the union of old LocoKit's
    /// `TimelineItem` / `Visit` / `Path` encoders and Arc's `ArcItem` / `ArcVisit` / `ArcPath`
    /// ones. `isVisit` is the only type discriminator. A deleted item is usually a tombstone
    /// carrying only `itemId`, `isVisit`, `lastSaved` and `deleted`.
    ///
    /// `startDate` / `endDate` are present whenever the source row had them (the backup writer
    /// encodes with `includeSamplesWhenEncoding = false`, which writes the stored range). The old
    /// app's own restore threw these away (`breakEdges()` nils `_dateRange`); we read them (BIG-399
    /// decision 2). Half of all visits in a real corpus have no `center`.
    public struct Item: Codable, Hashable, Sendable {

        // old LocoKit TimelineItem
        public let itemId: String
        public let isVisit: Bool
        public let deleted: Bool?
        public let disabled: Bool?
        public let lastSaved: Date?
        public let previousItemId: String?
        public let nextItemId: String?
        public let startDate: Date?
        public let endDate: Date?
        public let altitude: Double?
        public let stepCount: Double?          // pedometer count (old LocoKit); Migrate parity uses hkStepCount
        public let floorsAscended: Double?
        public let floorsDescended: Double?

        // old LocoKit Visit
        public let center: Coordinate?
        public let radius: Radius?

        // old LocoKit Path
        public let activityType: String?

        // ArcItem
        public let activeEnergyBurned: Double?
        public let averageHeartRate: Double?
        public let maxHeartRate: Double?
        public let hkStepCount: Double?

        // ArcVisit
        public let streetAddress: String?
        public let customTitle: String?
        public let placeId: String?
        public let manualPlace: Bool?
        public let swarmCheckinId: String?

        // ArcPath
        public let manualActivityType: Bool?
        public let unknownActivityType: Bool?
        public let uncertainActivityType: Bool?
        public let activityTypeConfidenceScore: Double?

        // MARK: -

        public var isDeleted: Bool { deleted ?? false }
        public var isDisabled: Bool { disabled ?? false }

        public var dateRange: DateInterval? {
            guard let startDate, let endDate, endDate >= startDate else { return nil }
            return DateInterval(start: startDate, end: endDate)
        }
    }
}
