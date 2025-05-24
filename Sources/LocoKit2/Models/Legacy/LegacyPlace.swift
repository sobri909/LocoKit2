//
//  LegacyPlace.swift
//
//
//  Created on 2025-05-20.
//

import Foundation
import CoreLocation
import GRDB

public struct LegacyPlace: FetchableRecord, TableRecord, Codable, Hashable, Sendable {
    public static var databaseTableName: String { return "Place" }
    
    public var placeId: String
    public var name: String?
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance
    public var radiusSD: CLLocationDistance
    public var streetAddress: String?
    public var secondsFromGMT: Int?
    
    // External place IDs
    public var mapboxPlaceId: String?
    public var mapboxCategory: String?
    public var mapboxMakiIcon: String?
    
    public var googlePlaceId: String?
    public var googlePrimaryType: String?
    
    public var foursquareVenueId: String?
    public var foursquareCategoryIntId: Int?
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}