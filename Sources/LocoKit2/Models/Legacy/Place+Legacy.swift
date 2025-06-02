//
//  Place+Legacy.swift
//  LocoKit2
//
//  Created on 2025-05-20
//

import Foundation
import CoreLocation

extension Place {
    public init(from legacyPlace: LegacyPlace) {
        self.init(
            coordinate: legacyPlace.coordinate,
            name: legacyPlace.name ?? "Unnamed Place",
            streetAddress: legacyPlace.streetAddress,
            secondsFromGMT: legacyPlace.secondsFromGMT,
            mapboxPlaceId: legacyPlace.mapboxPlaceId,
            mapboxCategory: legacyPlace.mapboxCategory,
            mapboxMakiIcon: legacyPlace.mapboxMakiIcon,
            googlePlaceId: legacyPlace.googlePlaceId,
            googlePrimaryType: legacyPlace.googlePrimaryType, 
            foursquarePlaceId: legacyPlace.foursquareVenueId,
            foursquareCategoryId: legacyPlace.foursquareCategoryIntId
        )
        
        self.id = legacyPlace.placeId
        self.radiusMean = legacyPlace.radiusMean
        self.radiusSD = legacyPlace.radiusSD
        self.source = "LocoKit"
    }
}
