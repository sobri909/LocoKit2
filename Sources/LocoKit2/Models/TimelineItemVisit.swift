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

    public static let minRadius: CLLocationDistance = 10
    public static let maxRadius: CLLocationDistance = 150

    public let itemId: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance
    public var radiusSD: CLLocationDistance

    public var placeId: String?
    public var confirmedPlace = false

    public var id: String { itemId }

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var centerLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    public var radius: Radius {
        Radius(mean: radiusMean, sd: radiusSD)
    }

    // MARK: -

    public func overlaps(_ otherVisit: TimelineItemVisit) -> Bool {
        return distance(from: otherVisit) < 0
    }

    public func distance(from otherVisit: TimelineItemVisit) -> CLLocationDistance {
        return centerLocation.distance(from: otherVisit.centerLocation) - radius.with1sd - otherVisit.radius.with1sd
    }

    public func distance(from otherItem: TimelineItem) -> CLLocationDistance? {
        if otherItem.isVisit, let otherVisit = otherItem.visit {
            return distance(from: otherVisit)
        }

        if otherItem.isTrip, let otherEdge = otherItem.edgeSample(withOtherItemId: self.id)?.location, otherEdge.coordinate.isUsable {
            return centerLocation.distance(from: otherEdge) - radius.with1sd
        }
        
        return nil
    }

    // MARK: -

    public mutating func update(from samples: [LocomotionSample]) -> Bool {
        let oldSelf = self

        let usableLocations = samples.compactMap { $0.location }.usableLocations()

        guard let coordinate = usableLocations.weightedCenter() else {
            return false
        }

        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let radius = usableLocations.radius(from: center)
        self.radiusMean = min(max(radius.mean, Self.minRadius), Self.maxRadius)
        self.radiusSD = min(radius.sd, Self.maxRadius)

        return !self.databaseEquals(oldSelf)
    }

    // MARK: - Init

    init?(itemId: String, samples: [LocomotionSample]) {
        let usableLocations = samples.compactMap { $0.location }.usableLocations()

        guard let coordinate = usableLocations.weightedCenter() else {
            return nil
        }

        self.itemId = itemId
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let radius = usableLocations.radius(from: center)
        self.radiusMean = min(max(radius.mean, Self.minRadius), Self.maxRadius)
        self.radiusSD = min(radius.sd, Self.maxRadius)
    }

}
