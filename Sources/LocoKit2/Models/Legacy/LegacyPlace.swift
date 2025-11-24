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

    // MARK: - Columns

    public enum Columns {
        public static let placeId = Column("placeId")
        public static let name = Column("name")
        public static let latitude = Column("latitude")
        public static let longitude = Column("longitude")
        public static let radiusMean = Column("radiusMean")
        public static let radiusSD = Column("radiusSD")
        public static let streetAddress = Column("streetAddress")
        public static let secondsFromGMT = Column("secondsFromGMT")
        public static let mapboxPlaceId = Column("mapboxPlaceId")
        public static let mapboxCategory = Column("mapboxCategory")
        public static let mapboxMakiIcon = Column("mapboxMakiIcon")
        public static let googlePlaceId = Column("googlePlaceId")
        public static let googlePrimaryType = Column("googlePrimaryType")
        public static let foursquareVenueId = Column("foursquareVenueId")
        public static let foursquareCategoryIntId = Column("foursquareCategoryIntId")
    }
}