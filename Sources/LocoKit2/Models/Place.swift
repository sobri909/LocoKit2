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
    public static let maximumPlaceRadius: CLLocationDistance = 2000
    public static let minimumNewPlaceRadius: CLLocationDistance = 60

    public var id: String = UUID().uuidString
    public var lastSaved: Date = .now
    public var source: String = "LocoKit2"

    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance = Place.minimumNewPlaceRadius
    public var radiusSD: CLLocationDistance = 0
    public var secondsFromGMT: Int?
    public var name: String
    public var streetAddress: String?
    public var countryCode: String?
    public var locality: String?
    public var isStale = true

    public var mapboxPlaceId: String?
    public var mapboxCategory: String?
    public var mapboxMakiIcon: String?
    public var googlePlaceId: String?
    public var googlePrimaryType: String?
    public var foursquarePlaceId: String?
    public var foursquareCategoryId: Int?

    public var rtreeId: Int64?
    
    public static let rtree = belongsTo(PlaceRTree.self, using: ForeignKey(["rtreeId"]))

    public var visitCount: Int = 0
    public var visitDays: Int = 0
    public var lastVisitDate: Date?
    public var arrivalTimes: Histogram?
    public var leavingTimes: Histogram?
    public var visitDurations: Histogram?
    public var occupancyTimes: [Histogram]?

    // MARK: - Computed properties

    public var center: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var radius: Radius {
        return Radius(mean: radiusMean, sd: radiusSD)
    }

    public var sourceDatabases: [PlaceSource] {
        var sources: [PlaceSource] = []
        if mapboxPlaceId != nil { sources.append(.mapbox) }
        if googlePlaceId != nil { sources.append(.google) }
        if foursquarePlaceId != nil { sources.append(.foursquare) }
        return sources
    }
    
    public var isPrivate: Bool {
        return sourceDatabases.isEmpty
    }
    
    public var countryName: String? {
        guard let countryCode else { return nil }
        return Locale.current.localizedString(forRegionCode: countryCode)
    }

    public var localTimeZone: TimeZone? {
        guard let secondsFromGMT else { return nil }
        return TimeZone(secondsFromGMT: secondsFromGMT)
    }

    // MARK: - Reverse Geocode

    @PlacesActor
    @discardableResult
    public func updateFromReverseGeocode() async throws -> Bool {
        if secondsFromGMT != nil && streetAddress != nil && countryCode != nil && locality != nil { return false }

        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(center.location)
            guard let placemark = placemarks.first else { return false }

            // attempt to construct a useful streetAddress
            let streetAddress = if placemark.name == placemark.postalCode {
                placemark.thoroughfare
                    ?? placemark.subLocality
                    ?? placemark.locality
                    ?? placemark.subAdministrativeArea
                    ?? placemark.administrativeArea
                    ?? placemark.postalCode
            } else {
                placemark.name
            }

            do {
                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        if let timeZone = placemark.timeZone {
                            $0.secondsFromGMT = timeZone.secondsFromGMT()
                        }
                        if let streetAddress {
                            $0.streetAddress = streetAddress
                        }
                        if let isoCountryCode = placemark.isoCountryCode {
                            $0.countryCode = isoCountryCode.lowercased()
                        }
                        if let city = placemark.locality {
                            $0.locality = city
                        }
                    }
                }
                return true

            } catch {
                Log.error(error, subsystem: .database)
            }

        } catch let error as CLError {
            if error.code == .network { throw error }
            Log.error(error, subsystem: .places)
            
        } catch {
            Log.error(error, subsystem: .places)
        }
        
        return false
    }

    // MARK: - Update Management
    
    @PlacesActor
    public func markStale() async {
        do {
            try await Database.pool.write { db in
                var mutableSelf = self
                try mutableSelf.updateChanges(db) {
                    $0.isStale = true
                }
            }
        } catch {
            Log.error(error, subsystem: .database)
        }
    }
    
    // MARK: - Init

    public init(
        coordinate: CLLocationCoordinate2D,
        name: String,
        streetAddress: String? = nil,
        countryCode: String? = nil,
        locality: String? = nil,
        secondsFromGMT: Int? = nil,
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
        self.countryCode = countryCode
        self.locality = locality
        self.secondsFromGMT = secondsFromGMT

        self.mapboxPlaceId = mapboxPlaceId
        self.mapboxCategory = mapboxCategory
        self.mapboxMakiIcon = mapboxMakiIcon

        self.googlePlaceId = googlePlaceId
        self.googlePrimaryType = googlePrimaryType

        self.foursquarePlaceId = foursquarePlaceId
        self.foursquareCategoryId = foursquareCategoryId
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case lastSaved
        case source
        case latitude
        case longitude
        case radiusMean
        case radiusSD
        case secondsFromGMT
        case name
        case streetAddress
        case countryCode
        case locality
        case isStale

        case rtreeId

        case mapboxPlaceId
        case mapboxCategory
        case mapboxMakiIcon
        case googlePlaceId
        case googlePrimaryType
        case foursquarePlaceId
        case foursquareCategoryId

        case visitCount
        case visitDays
        case lastVisitDate
    }

    // MARK: - Columns

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let lastSaved = Column(CodingKeys.lastSaved)
        public static let source = Column(CodingKeys.source)
        public static let latitude = Column(CodingKeys.latitude)
        public static let longitude = Column(CodingKeys.longitude)
        public static let radiusMean = Column(CodingKeys.radiusMean)
        public static let radiusSD = Column(CodingKeys.radiusSD)
        public static let secondsFromGMT = Column(CodingKeys.secondsFromGMT)
        public static let name = Column(CodingKeys.name)
        public static let streetAddress = Column(CodingKeys.streetAddress)
        public static let countryCode = Column(CodingKeys.countryCode)
        public static let locality = Column(CodingKeys.locality)
        public static let isStale = Column(CodingKeys.isStale)
        public static let rtreeId = Column(CodingKeys.rtreeId)
        public static let mapboxPlaceId = Column(CodingKeys.mapboxPlaceId)
        public static let mapboxCategory = Column(CodingKeys.mapboxCategory)
        public static let mapboxMakiIcon = Column(CodingKeys.mapboxMakiIcon)
        public static let googlePlaceId = Column(CodingKeys.googlePlaceId)
        public static let googlePrimaryType = Column(CodingKeys.googlePrimaryType)
        public static let foursquarePlaceId = Column(CodingKeys.foursquarePlaceId)
        public static let foursquareCategoryId = Column(CodingKeys.foursquareCategoryId)
        public static let visitCount = Column(CodingKeys.visitCount)
        public static let visitDays = Column(CodingKeys.visitDays)
        public static let lastVisitDate = Column(CodingKeys.lastVisitDate)

        // histogram columns (not in CodingKeys)
        public static let arrivalTimes = Column("arrivalTimes")
        public static let leavingTimes = Column("leavingTimes")
        public static let visitDurations = Column("visitDurations")
        public static let occupancyTimes = Column("occupancyTimes")

        // all columns except histograms (for efficient bulk loading)
        public static let columnsExcludingHistograms: [Column] = [
            id, lastSaved, source, latitude, longitude, radiusMean, radiusSD,
            secondsFromGMT, name, streetAddress, countryCode, locality, isStale,
            rtreeId, mapboxPlaceId, mapboxCategory, mapboxMakiIcon, googlePlaceId,
            googlePrimaryType, foursquarePlaceId, foursquareCategoryId,
            visitCount, visitDays, lastVisitDate
        ]
    }

    // MARK: - Custom Decoder

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // core fields
        id = try container.decode(String.self, forKey: .id)
        lastSaved = try container.decode(Date.self, forKey: .lastSaved)
        // graceful handling for missing source field (backwards compatibility)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "LocoKit2"
        latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        radiusMean = try container.decode(CLLocationDistance.self, forKey: .radiusMean)
        radiusSD = try container.decode(CLLocationDistance.self, forKey: .radiusSD)
        secondsFromGMT = try container.decodeIfPresent(Int.self, forKey: .secondsFromGMT)
        name = try container.decode(String.self, forKey: .name)
        streetAddress = try container.decodeIfPresent(String.self, forKey: .streetAddress)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        locality = try container.decodeIfPresent(String.self, forKey: .locality)
        isStale = try container.decode(Bool.self, forKey: .isStale)
        rtreeId = try container.decodeIfPresent(Int64.self, forKey: .rtreeId)
        
        // external place ids
        mapboxPlaceId = try container.decodeIfPresent(String.self, forKey: .mapboxPlaceId)
        mapboxCategory = try container.decodeIfPresent(String.self, forKey: .mapboxCategory)
        mapboxMakiIcon = try container.decodeIfPresent(String.self, forKey: .mapboxMakiIcon)
        googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        googlePrimaryType = try container.decodeIfPresent(String.self, forKey: .googlePrimaryType)
        foursquarePlaceId = try container.decodeIfPresent(String.self, forKey: .foursquarePlaceId)
        foursquareCategoryId = try container.decodeIfPresent(Int.self, forKey: .foursquareCategoryId)
        
        // stats
        visitCount = try container.decodeIfPresent(Int.self, forKey: .visitCount) ?? 0
        visitDays = try container.decodeIfPresent(Int.self, forKey: .visitDays) ?? 0
        lastVisitDate = try container.decodeIfPresent(Date.self, forKey: .lastVisitDate)

        // histograms default to nil (not included in JSON export/import)
        arrivalTimes = nil
        leavingTimes = nil
        visitDurations = nil
        occupancyTimes = nil
    }

    // MARK: - FetchableRecord

    public init(row: Row) throws {
        // core fields
        id = row["id"]
        lastSaved = row["lastSaved"]
        source = row["source"]
        latitude = row["latitude"]
        longitude = row["longitude"]
        radiusMean = row["radiusMean"]
        radiusSD = row["radiusSD"]
        secondsFromGMT = row["secondsFromGMT"]
        name = row["name"]
        streetAddress = row["streetAddress"]
        countryCode = row["countryCode"]
        locality = row["locality"]
        isStale = row["isStale"]
        rtreeId = row["rtreeId"]

        // external place ids
        mapboxPlaceId = row["mapboxPlaceId"]
        mapboxCategory = row["mapboxCategory"]
        mapboxMakiIcon = row["mapboxMakiIcon"]
        googlePlaceId = row["googlePlaceId"]
        googlePrimaryType = row["googlePrimaryType"]
        foursquarePlaceId = row["foursquarePlaceId"]
        foursquareCategoryId = row["foursquareCategoryId"]

        // stats
        visitCount = row["visitCount"]
        visitDays = row["visitDays"]
        lastVisitDate = row["lastVisitDate"]

        // Histograms with MessagePack
        let decoder = JSONDecoder()
        if let data = row["arrivalTimes"] as? Data {
            arrivalTimes = try? decoder.decode(Histogram.self, from: data)
        }
        if let data = row["leavingTimes"] as? Data {
            leavingTimes = try? decoder.decode(Histogram.self, from: data)
        }
        if let data = row["visitDurations"] as? Data {
            visitDurations = try? decoder.decode(Histogram.self, from: data)
        }
        if let data = row["occupancyTimes"] as? Data {
            occupancyTimes = try? decoder.decode([Histogram].self, from: data)
        }
    }

    // MARK: - PersistableRecord
    
    public func encode(to container: inout PersistenceContainer) {
        // core fields
        container["id"] = id
        container["lastSaved"] = lastSaved
        container["source"] = source

        container["latitude"] = latitude
        container["longitude"] = longitude
        container["radiusMean"] = radiusMean
        container["radiusSD"] = radiusSD
        container["secondsFromGMT"] = secondsFromGMT
        container["name"] = name
        container["streetAddress"] = streetAddress
        container["countryCode"] = countryCode
        container["locality"] = locality
        container["isStale"] = isStale
        container["rtreeId"] = rtreeId

        // external place ids
        container["mapboxPlaceId"] = mapboxPlaceId
        container["mapboxCategory"] = mapboxCategory
        container["mapboxMakiIcon"] = mapboxMakiIcon
        container["googlePlaceId"] = googlePlaceId
        container["googlePrimaryType"] = googlePrimaryType
        container["foursquarePlaceId"] = foursquarePlaceId
        container["foursquareCategoryId"] = foursquareCategoryId

        // stats
        container["visitCount"] = visitCount
        container["visitDays"] = visitDays
        container["lastVisitDate"] = lastVisitDate

        // Histograms
        let encoder = JSONEncoder()
        container["arrivalTimes"] = try? encoder.encode(arrivalTimes)
        container["leavingTimes"] = try? encoder.encode(leavingTimes)
        container["visitDurations"] = try? encoder.encode(visitDurations)
        container["occupancyTimes"] = try? encoder.encode(occupancyTimes)
    }

}
