//
//  ImportHelpers.swift
//  LocoKit2
//
//  Created on 2025-10-15
//

import Foundation
import GRDB

@ImportExportActor
public enum ImportHelpers {

    /// Create preserved parent items for disabled samples from enabled parents
    ///
    /// Handles scenario 2 mismatches where samples are disabled but their parent item is enabled.
    /// Creates new disabled parent items (Visit or Trip) matching the original type, copies metadata,
    /// and reassigns the disabled samples to the preserved parents.
    public static func createPreservedParentItems(
        for disabledSamplesFromEnabledParents: [String: [LocomotionSample]]
    ) async throws {
        let totalScenario2Samples = disabledSamplesFromEnabledParents.values.reduce(0) { $0 + $1.count }
        logger.info("Creating preserved parent items for \(disabledSamplesFromEnabledParents.count) items with \(totalScenario2Samples) disabled samples", subsystem: .importing)

        let (visitCount, tripCount) = try await Database.pool.write { db -> (Int, Int) in
            var visits = 0
            var trips = 0

            for (originalItemId, disabledSamples) in disabledSamplesFromEnabledParents {
                // fetch original item to determine type and copy metadata
                guard let originalItem = try TimelineItem.itemRequest(includeSamples: false).filter(Column("id") == originalItemId).fetchOne(db) else {
                    logger.info("Could not find original item \(originalItemId) for preserved parent creation", subsystem: .importing)
                    continue
                }

                // create preserved parent matching original type
                var preservedBase = TimelineItemBase(isVisit: originalItem.base.isVisit)
                preservedBase.source = originalItem.base.source
                preservedBase.disabled = true

                try preservedBase.insert(db)

                // create visit or trip component with metadata
                if originalItem.base.isVisit, let originalVisit = originalItem.visit {
                    visits += 1

                    var preservedVisit = TimelineItemVisit(
                        itemId: preservedBase.id,
                        latitude: originalVisit.latitude,
                        longitude: originalVisit.longitude,
                        radiusMean: originalVisit.radiusMean,
                        radiusSD: originalVisit.radiusSD
                    )
                    preservedVisit.copyMetadata(from: originalVisit)
                    try preservedVisit.insert(db)

                } else if !originalItem.base.isVisit, let originalTrip = originalItem.trip {
                    trips += 1

                    var preservedTrip = TimelineItemTrip(itemId: preservedBase.id, samples: [])
                    preservedTrip.classifiedActivityType = originalTrip.classifiedActivityType
                    preservedTrip.confirmedActivityType = originalTrip.confirmedActivityType
                    preservedTrip.uncertainActivityType = originalTrip.uncertainActivityType
                    try preservedTrip.insert(db)
                }

                // reassign disabled samples to preserved parent
                for var sample in disabledSamples {
                    try sample.updateChanges(db) {
                        $0.timelineItemId = preservedBase.id
                    }
                }
            }

            return (visits, trips)
        }

        // log summary stats
        print("Preserved parent summary:")
        print("- Total items: \(disabledSamplesFromEnabledParents.count)")
        print("- Visits: \(visitCount), Trips: \(tripCount)")
        print("- Total samples: \(totalScenario2Samples)")

        let sampleCounts = disabledSamplesFromEnabledParents.mapValues { $0.count }
        if !sampleCounts.isEmpty {
            let counts = sampleCounts.values
            let minSamples = counts.min() ?? 0
            let maxSamples = counts.max() ?? 0
            let avgSamples = counts.reduce(0, +) / counts.count
            print("- Sample counts: min=\(minSamples), max=\(maxSamples), avg=\(avgSamples)")

            // top 10 by sample count
            let sorted = sampleCounts.sorted { $0.value > $1.value }
            print("- Top 10 items by sample count:")
            for (itemId, count) in sorted.prefix(10) {
                print("  - Item \(itemId): \(count) samples")
            }
        }

        logger.info("Created \(disabledSamplesFromEnabledParents.count) preserved parent items (\(visitCount) visits, \(tripCount) trips)", subsystem: .importing)
    }
}
