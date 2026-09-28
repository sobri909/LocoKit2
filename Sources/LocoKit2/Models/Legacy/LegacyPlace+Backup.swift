//
//  LegacyPlace+Backup.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyPlace {

    /// A backup-file place as the sqlite-shaped `LegacyPlace` the AT3 → LocoKit2 converter
    /// takes (BIG-399). The one active defence: a place written during the Nov-2023 encoder bug
    /// carries its own id in `mapboxCategory` and `mapboxMakiIcon`; both are dropped rather
    /// than imported as a category string nothing can match.
    init(backup place: LegacyBackup.Place) {
        let mapboxCorrupt = place.hasMapboxCopyPasteCorruption
        self.init(
            placeId: place.placeId,
            name: place.name,
            latitude: place.center.latitude,
            longitude: place.center.longitude,
            radiusMean: place.radius.mean,
            radiusSD: place.radius.sd,
            streetAddress: place.streetAddress,
            secondsFromGMT: place.secondsFromGMT,
            mapboxPlaceId: place.mapboxPlaceId,
            mapboxCategory: mapboxCorrupt ? nil : place.mapboxCategory,
            mapboxMakiIcon: mapboxCorrupt ? nil : place.mapboxMakiIcon,
            googlePlaceId: place.googlePlaceId,
            googlePrimaryType: place.googlePrimaryType,
            foursquareVenueId: place.foursquareVenueId,
            foursquareCategoryId: place.foursquareCategoryId,
            foursquareCategoryIntId: place.foursquareCategoryIntId
        )
    }
}
