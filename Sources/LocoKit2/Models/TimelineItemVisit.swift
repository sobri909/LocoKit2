//
//  TimelineItemVisit.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
@preconcurrency import GRDB

public struct TimelineItemVisit: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public static let minimumKeeperDuration: TimeInterval = .minutes(2)
    public static let minimumValidDuration: TimeInterval = 10

    public static let minRadius: CLLocationDistance = 10
    public static let maxRadius: CLLocationDistance = 150

    public let itemId: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance
    public var radiusSD: CLLocationDistance

    public var placeId: String?
    public var confirmedPlace = false
    public var uncertainPlace = true

    public var customTitle: String?
    public var streetAddress: String?

    public static let place = belongsTo(Place.self, using: ForeignKey(["placeId"]))

    public var id: String { itemId }

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var radius: Radius {
        Radius(mean: radiusMean, sd: radiusSD)
    }

    // MARK: - Init

    init?(itemId: String, samples: [LocomotionSample]) {
        guard let coordinate = samples.weightedCenter() else {
            return nil
        }

        self.itemId = itemId
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let center = CLLocation(coordinate: coordinate)
        let radius = Self.calculateBoundedRadius(of: samples, from: center)

        self.radiusMean = radius.mean
        self.radiusSD = radius.sd
    }

    // MARK: - Comparisons etc

    public func overlaps(_ otherVisit: TimelineItemVisit) -> Bool {
        return distance(from: otherVisit) < 0
    }

    public func distance(from otherVisit: TimelineItemVisit) -> CLLocationDistance {
        return center.location.distance(from: otherVisit.center.location) - radius.with1sd - otherVisit.radius.with1sd
    }

    public func distance(from otherItem: TimelineItem) throws -> CLLocationDistance? {
        if otherItem.isVisit, let otherVisit = otherItem.visit {
            return distance(from: otherVisit)
        }

        if otherItem.isTrip, let otherEdge = try otherItem.edgeSample(withOtherItemId: self.id)?.location, otherEdge.coordinate.isUsable {
            return center.location.distance(from: otherEdge) - radius.with1sd
        }
        
        return nil
    }

    public func contains(_ location: CLLocation, sd: Double) -> Bool {
        let testRadius = radius.withSD(sd).clamped(min: Self.minRadius, max: Self.maxRadius)
        return location.distance(from: center.location) <= testRadius
    }

    // MARK: - Place

    public func assignPlace(_ place: Place, confirm: Bool = false, uncertain: Bool = false) async {
        // cannot be both confirmed and uncertain
        if confirm && uncertain {
            fatalError("Cannot have a confirmed place that is uncertain")
        }

        // don't overwrite a confirmed assignment with an unconfirmed one
        if !confirm, confirmedPlace, placeId != nil { return }

        let previousPlaceId = placeId

        do {
            try await Database.pool.write { db in
                var mutableSelf = self
                try mutableSelf.updateChanges(db) {
                    $0.placeId = place.id
                    $0.confirmedPlace = confirm
                    $0.uncertainPlace = uncertain
                    $0.customTitle = nil
                }
                var mutablePlace = place
                try mutablePlace.updateChanges(db) {
                    $0.isStale = true
                }
                if let previousPlaceId {
                    var previousPlace = try Place.fetchOne(db, id: previousPlaceId)
                    try previousPlace?.updateChanges(db) {
                        $0.isStale = true
                    }
                }
            }

            // update stats for the new place
            Task {
                var mutablePlace = place
                await mutablePlace.updateVisitStats()
            }

            // update stats for the previous place if there was one
            if let previousPlaceId {
                Task {
                    do {
                        var previousPlace = try await Database.pool.read { try Place.fetchOne($0, id: previousPlaceId) }
                        await previousPlace?.updateVisitStats()
                    } catch {
                        logger.error(error, subsystem: .database)
                    }
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public var hasConfirmedPlace: Bool { placeId != nil && confirmedPlace }

    public func hasSamePlaceAs(_ other: TimelineItemVisit) -> Bool {
        guard let placeId = self.placeId, let otherPlaceId = other.placeId else {
            return false
        }
        return placeId == otherPlaceId
    }
    
    // MARK: - Updating

    public mutating func update(from samples: [LocomotionSample]) async {
        guard let coordinate = samples.weightedCenter() else {
            return
        }

        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let radius = Self.calculateBoundedRadius(of: samples, from: coordinate.location)

        self.radiusMean = radius.mean
        self.radiusSD = radius.sd
    }

    static func calculateBoundedRadius(of samples: [LocomotionSample], from center: CLLocation) -> Radius {
        let radius = samples.weightedRadius(from: center)
        let boundedMean = min(max(radius.mean, Self.minRadius), Self.maxRadius)
        let boundedSD = min(radius.sd, Self.maxRadius)
        return Radius(mean: boundedMean, sd: boundedSD)
    }

    public mutating func copyMetadata(from otherVisit: TimelineItemVisit) {
        placeId = otherVisit.placeId
        confirmedPlace = otherVisit.confirmedPlace
        customTitle = otherVisit.customTitle
        streetAddress = otherVisit.streetAddress
    }

}
