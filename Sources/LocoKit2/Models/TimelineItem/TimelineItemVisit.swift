//
//  TimelineItemVisit.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItemVisit: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {


    public static let minimumKeeperDuration: TimeInterval = .minutes(2)
    public static let minimumValidDuration: TimeInterval = 10

    public static let minRadius: CLLocationDistance = 10
    public static let maxRadius: CLLocationDistance = 150

    public let itemId: String
    public var lastSaved: Date = .now
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
    
    // direct initialiser for imports and other special cases
    public init(
        itemId: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        radiusMean: CLLocationDistance,
        radiusSD: CLLocationDistance
    ) {
        self.itemId = itemId
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMean = radiusMean
        self.radiusSD = radiusSD
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
        // don't overwrite a confirmed assignment with an unconfirmed one
        if !confirm, confirmedPlace, placeId != nil { return }

        let previousPlaceId = placeId

        do {
            try await Database.pool.write { db in
                var mutableSelf = self
                try mutableSelf.updateChanges(db) {
                    $0.placeId = place.id
                    $0.confirmedPlace = confirm
                    $0.setUncertainty(uncertain)
                    $0.customTitle = nil
                }
            }

            Task {
                await place.markStale()

                // only update immediately if user-confirmed and visit count is low
                if confirm && place.visitCount < 30 {
                    await place.updateVisitStats()
                }
                
                if let previousPlaceId {
                    do {
                        let previousPlace = try await Database.pool.read { try Place.fetchOne($0, id: previousPlaceId) }
                        if let previousPlace {
                            await previousPlace.markStale()
                            
                            // same immediate update criteria for previous place
                            if confirm && previousPlace.visitCount < 30 {
                                await previousPlace.updateVisitStats()
                            }
                        }

                    } catch {
                        logger.error(error, subsystem: .database)
                    }
                }
            }

            // process timeline changes after place assignment
            await TimelineProcessor.processFrom(itemId: itemId)

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

    public mutating func setUncertainty(_ uncertain: Bool) {
        if uncertain {
            // Can only be uncertain if not confirmed
            uncertainPlace = confirmedPlace ? false : uncertain
        } else {
            // Can only be certain if have a place
            uncertainPlace = placeId == nil ? true : uncertain
        }
    }
    
    public mutating func copyMetadata(from otherVisit: TimelineItemVisit) {
        placeId = otherVisit.placeId
        confirmedPlace = otherVisit.confirmedPlace
        setUncertainty(otherVisit.uncertainPlace)
        customTitle = otherVisit.customTitle
        streetAddress = otherVisit.streetAddress
    }

    // MARK: - Columns

    public enum Columns {
        public static let itemId = Column(CodingKeys.itemId)
        public static let lastSaved = Column(CodingKeys.lastSaved)
        public static let latitude = Column(CodingKeys.latitude)
        public static let longitude = Column(CodingKeys.longitude)
        public static let radiusMean = Column(CodingKeys.radiusMean)
        public static let radiusSD = Column(CodingKeys.radiusSD)
        public static let placeId = Column(CodingKeys.placeId)
        public static let confirmedPlace = Column(CodingKeys.confirmedPlace)
        public static let uncertainPlace = Column(CodingKeys.uncertainPlace)
        public static let customTitle = Column(CodingKeys.customTitle)
        public static let streetAddress = Column(CodingKeys.streetAddress)
    }

}
