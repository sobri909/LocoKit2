//
//  Place.swift
//
//
//  Created by Matt Greenfield on 25/3/24.
//

import Foundation
import CoreLocation
import GRDB

public enum PlaceSource { case google, foursquare, mapbox }

public struct Place: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public static let minimumPlaceRadius: CLLocationDistance = 8
    public static let minimumNewPlaceRadius: CLLocationDistance = 60

    public var id: String = UUID().uuidString
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance = Place.minimumNewPlaceRadius
    public var radiusSD: CLLocationDistance = 0
    public var secondsFromGMT: Int?

    public var name: String
    public var streetAddress: String?

    public var mapboxPlaceId: String?
    public var mapboxCategory: String?
    public var mapboxMakiIcon: String?

    public var googlePlaceId: String?
    public var googlePrimaryType: String?

    public var foursquarePlaceId: String?
    public var foursquareCategoryId: Int?

    public var rtreeId: Int64?

    public var isStale = false

    // MARK: - Computed properties

    public var localTimeZone: TimeZone? {
        if let secondsFromGMT {
            return TimeZone(secondsFromGMT: secondsFromGMT)
        }
        return nil
    }

    public var center: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var radius: Radius {
        return Radius(mean: radiusMean, sd: radiusSD)
    }

    var sourceDatabases: [PlaceSource] {
        var sources: [PlaceSource] = []
        if mapboxPlaceId != nil { sources.append(.mapbox) }
        if googlePlaceId != nil { sources.append(.google) }
        if foursquarePlaceId != nil { sources.append(.foursquare) }
        return sources
    }


    // MARK: - Overlaps

    public func overlaps(_ visit: TimelineItemVisit) -> Bool {
        return distance(from: visit) < 0
    }

    public func overlaps(_ segment: ItemSegment) -> Bool {
        if let distance = distance(from: segment) {
            return distance < 0
        }
        return false
    }

    public func overlaps(_ otherPlace: Place) -> Bool {
        return distance(from: otherPlace) < 0
    }

    // TODO: Arc Timeline uses 4sd if visitCount is < 2
    public func distance(from visit: TimelineItemVisit) -> CLLocationDistance {
        return center.location.distance(from: visit.center.location) - radius.with3sd - visit.radius.with1sd
    }

    public func distance(from segment: ItemSegment) -> CLLocationDistance? {
        guard let segmentCenter = segment.center, let segmentRadius = segment.radius else { return nil }
        return center.location.distance(from: segmentCenter.location) - radius.with3sd - segmentRadius.with2sd
    }

    public func distance(from otherPlace: Place) -> CLLocationDistance {
        return center.location.distance(from: otherPlace.center.location) - radius.with3sd - otherPlace.radius.with3sd
    }

    // MARK: - Init

    public init(
        coordinate: CLLocationCoordinate2D,
        name: String,
        streetAddress: String? = nil,
        mapboxPlaceId: String? = nil,
        mapboxCategory: String? = nil,
        mapboxMakiIcon: String? = nil,
        googlePlaceId: String? = nil,
        googlePrimaryType: String? = nil,
        foursquarePlaceId: String? = nil,
        foursquareCategoryId: Int? = nil
    ) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.name = name
        self.streetAddress = streetAddress

        self.mapboxPlaceId = mapboxPlaceId
        self.mapboxCategory = mapboxCategory
        self.mapboxMakiIcon = mapboxMakiIcon

        self.googlePlaceId = googlePlaceId
        self.googlePrimaryType = googlePrimaryType

        self.foursquarePlaceId = foursquarePlaceId
        self.foursquareCategoryId = foursquareCategoryId
        self.isStale = true
    }

}
