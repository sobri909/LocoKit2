//
//  LegacyItem+Backup.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyItem {

    /// A backup-file item as the sqlite-shaped `LegacyItem` the AT3 → LocoKit2 converter takes
    /// (BIG-399). Differences from the sqlite row, on purpose:
    /// - `startDate` / `endDate` come from the file, for the record; LocoKit2 derives an item's
    ///   dates from its samples (trigger-maintained), so what actually keeps an item from
    ///   landing as a dateless shell is that the importer only imports items its live samples
    ///   reference. The old app's restore nilled the dates AND imported sample-less items
    ///   (BIG-776's 56k shells).
    /// - `previousItemId` / `nextItemId` are nil: the neighbours are rarely in the set, and
    ///   edge healing rebuilds them as items land in days (the edge-nilling half of the old
    ///   app's `breakEdges()`, kept).
    /// - `source` is synthesised as "LocoKit" (absent from the file; the migration gates key off it).
    /// - `stepCount` follows Migrate's choice and reads the HealthKit count only; the old
    ///   pedometer `stepCount` and the floors counts are not carried, so a Migrate-then-import
    ///   of the same item yields the same row.
    init(backup item: LegacyBackup.Item) {
        self.itemId = item.itemId
        self.isVisit = item.isVisit
        self.startDate = item.dateRange?.start
        self.endDate = item.dateRange?.end
        self.source = "LocoKit"
        self.deleted = item.isDeleted
        self.disabled = item.isDisabled

        self.placeId = item.placeId
        self.manualPlace = item.manualPlace
        self.streetAddress = item.streetAddress
        self.customTitle = item.customTitle
        self.latitude = item.center?.latitude
        self.longitude = item.center?.longitude
        self.radiusMean = item.radius?.mean
        self.radiusSD = item.radius?.sd

        self.distance = nil  // never encoded by the old app; recomputed from samples
        self.manualActivityType = item.manualActivityType
        self.activityType = item.activityType
        self.activityTypeConfidenceScore = item.activityTypeConfidenceScore

        self.activeEnergyBurned = item.activeEnergyBurned
        self.averageHeartRate = item.averageHeartRate
        self.maxHeartRate = item.maxHeartRate
        self.hkStepCount = item.hkStepCount

        self.previousItemId = nil
        self.nextItemId = nil
    }
}
