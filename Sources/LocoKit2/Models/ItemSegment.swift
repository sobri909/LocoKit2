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

    public var id: String { samples.first!.id }

    // MARK: - Init

    public init?(samples: [LocomotionSample], manualActivityType: ActivityType? = nil) {
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
    }

    // MARK: - Computed properties

    public var coordinates: [CLLocationCoordinate2D] {
        return samples.compactMap { $0.coordinate }.filter { $0.isUsable }
    }

    public var center: CLLocationCoordinate2D? {
        let usableLocations = samples.compactMap { $0.location }.usableLocations()
        return usableLocations.weightedCenter()
    }

    public var radius: Radius? {
        guard let center else { return nil }
        let usableLocations = samples.compactMap { $0.location }.usableLocations()
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return TimelineItemVisit.calculateBoundedRadius(of: usableLocations, from: location)
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
