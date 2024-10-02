//
//  ItemSegment.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-09-25.
//

import Foundation

public struct ItemSegment: Hashable, Sendable {
    public let samples: [LocomotionSample]
    public let dateRange: DateInterval

    init?(samples: [LocomotionSample]) {
        if samples.isEmpty {
            return nil
        }

        let dates = samples.map { $0.date }
        guard let startDate = dates.min(), let endDate = dates.max() else {
            return nil
        }

        self.samples = samples
        self.dateRange = DateInterval(start: startDate, end: endDate)
    }

    // MARK: - ActivityTypes

    public var activityType: ActivityType? {
        return samples.first?.activityType
    }

    public func confirmActivityType(_ confirmedType: ActivityType) async {
        do {
            try await Database.pool.write { db in
                for var sample in samples where sample.confirmedActivityType != confirmedType {
                    try sample.updateChanges(db) {
                        $0.confirmedActivityType = confirmedType
                    }
                }
            }

            await CoreMLModelUpdater.highlander.queueUpdatesForModelsContaining(samples)

        } catch {
            logger.error(error, subsystem: .database)
        }
    }
}
