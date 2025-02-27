//
//  ItemSegment.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-09-25.
//

import Foundation
import CoreLocation
import GRDB

public struct ItemSegment: Hashable, Identifiable, Sendable {
    
    public let samples: [LocomotionSample]
    public let dateRange: DateInterval
    public var manualActivityType: ActivityType?
    public var tag: Int?

    public var id: String { samples.first!.id }

    // MARK: - Init

    public init?(samples: [LocomotionSample], manualActivityType: ActivityType? = nil, tag: Int? = nil) {
        if samples.isEmpty {
            return nil
        }

        let dates = samples.map { $0.date }
        guard let startDate = dates.min(), let endDate = dates.max() else {
            return nil
        }

        self.samples = samples.sorted { $0.date < $1.date }
        self.dateRange = DateInterval(start: startDate, end: endDate)
        self.manualActivityType = manualActivityType
        self.tag = tag
    }

    // MARK: - Computed properties

    public var coordinates: [CLLocationCoordinate2D] {
        return samples.compactMap { $0.coordinate }.filter { $0.isUsable }
    }

    public var center: CLLocationCoordinate2D? {
        return samples.weightedCenter()
    }

    public var radius: Radius? {
        guard let center else { return nil }
        return samples.usableLocations().radius(from: center.location)
    }

    public var distance: CLLocationDistance {
        return samples.usableLocations().distance() ?? 0
    }

    public var isDataGap: Bool {
        return !samples.contains { $0.recordingState != .off }
    }

    public var isNolo: Bool {
        if activityType == .bogus { return false }
        return !samples.haveAnyUsableCoordinates()
    }

    // MARK: - Validity

    // there's no extra samples either in segment or db for the segment's dateRange
    public func validateIsContiguous() async throws -> Bool {
        let dbSampleIds = try await Database.pool.read { db in
            let request = LocomotionSample
                .select(Column("id"))
                .filter(dateRange.range.contains(Column("date")))
            return try String.fetchSet(db, request)
        }

        return dbSampleIds == Set(samples.map { $0.id })
    }

    // MARK: - ActivityTypes

    public var activityType: ActivityType? {
        return manualActivityType ?? samples.first?.activityType
    }

    public func confirmActivityType(_ confirmedType: ActivityType) async {
        do {
            let changedSamples = try await Database.pool.write { db in
                var changed: [LocomotionSample] = []
                for var sample in samples where sample.confirmedActivityType != confirmedType {
                    try sample.updateChanges(db) {
                        $0.confirmedActivityType = confirmedType
                    }
                    changed.append(sample)
                }
                return changed
            }

            await CoreMLModelUpdater.queueUpdatesForModelsContaining(changedSamples)

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

}
