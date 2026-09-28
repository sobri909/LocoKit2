//
//  LegacyBackup+Place.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyBackup {

    /// One `Place/<prefix>/<placeId>.json` file, from Arc's `Place.encode`. Only places with
    /// at least one visit were ever backed up. `foursquareCategoryId` is the Foursquare v2
    /// STRING id (LocoKit2's `Place.foursquareCategoryV2Id`); `foursquareCategoryIntId` is v3.
    ///
    /// For one week (2023-11-02 → 11-09) the encoder wrote `mapboxPlaceId` into both
    /// `mapboxCategory` and `mapboxMakiIcon` (copy-paste bug, fixed `e3131c47`). Those files
    /// decode cleanly as garbage; `hasMapboxCopyPasteCorruption` detects them, and the adapter
    /// nils both fields when it does.
    public struct Place: Codable, Hashable, Sendable {
        public let placeId: String
        public let name: String?
        public let center: Coordinate
        public let radius: Radius
        public let streetAddress: String?
        public let secondsFromGMT: Int?
        public let lastSaved: Date?

        public let mapboxPlaceId: String?
        public let mapboxCategory: String?
        public let mapboxMakiIcon: String?
        public let googlePlaceId: String?
        public let googlePrimaryType: String?
        public let foursquareVenueId: String?
        public let foursquareCategoryId: String?
        public let foursquareCategoryIntId: Int?

        // MARK: -

        /// The Nov-2023 encoder bug: the place id string sitting in the category field.
        public var hasMapboxCopyPasteCorruption: Bool {
            guard let mapboxPlaceId, let mapboxCategory else { return false }
            return mapboxCategory == mapboxPlaceId
        }
    }
}
