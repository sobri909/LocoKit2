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

    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance = Place.minimumNewPlaceRadius
    public var radiusSD: CLLocationDistance = 0
    public var secondsFromGMT: Int?
    public var name: String
    public var streetAddress: String?
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

    // MARK: - Timezone

    public var localTimeZone: TimeZone? {
        guard let secondsFromGMT else { return nil }
        return TimeZone(secondsFromGMT: secondsFromGMT)
    }

    @PlacesActor
    @discardableResult
    public func updateFromReverseGeocode() async throws -> Bool {
        if secondsFromGMT != nil && streetAddress != nil { return false }

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
                    }
                }
                return true

            } catch {
                logger.error(error, subsystem: .database)
            }

        } catch let error as CLError {
            if error.code == .network { throw error }
            logger.error(error, subsystem: .places)
            
        } catch {
            logger.error(error, subsystem: .places)
        }
        
        return false
    }

    // MARK: - RTree

    public func updateRTree() async {
        do {
            if let rtreeId {
                let rtree = PlaceRTree(
                    id: rtreeId,
                    latMin: center.latitude, latMax: center.latitude,
                    lonMin: center.longitude, lonMax: center.longitude
                )
                try await Database.pool.write {
                    try rtree.update($0)
                }

            } else {
                try await Database.pool.write { [self] db in
                    var rtree = PlaceRTree(
                        latMin: center.latitude, latMax: center.latitude,
                        lonMin: center.longitude, lonMax: center.longitude
                    )
                    try rtree.insert(db)

                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.rtreeId = rtree.id
                    }
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Init

    public init(
        coordinate: CLLocationCoordinate2D,
        name: String,
        streetAddress: String? = nil,
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
        case latitude
        case longitude
        case radiusMean
        case radiusSD
        case secondsFromGMT
        case name
        case streetAddress
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
    }

    // MARK: - FetchableRecord

    public init(row: Row) throws {
        // core fields
        id = row["id"]
        lastSaved = row["lastSaved"]
        latitude = row["latitude"]
        longitude = row["longitude"]
        radiusMean = row["radiusMean"]
        radiusSD = row["radiusSD"]
        secondsFromGMT = row["secondsFromGMT"]
        name = row["name"]
        streetAddress = row["streetAddress"]
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

        container["latitude"] = latitude
        container["longitude"] = longitude
        container["radiusMean"] = radiusMean
        container["radiusSD"] = radiusSD
        container["secondsFromGMT"] = secondsFromGMT
        container["name"] = name
        container["streetAddress"] = streetAddress
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

        // Histograms
        let encoder = JSONEncoder()
        container["arrivalTimes"] = try? encoder.encode(arrivalTimes)
        container["leavingTimes"] = try? encoder.encode(leavingTimes)
        container["visitDurations"] = try? encoder.encode(visitDurations)
        container["occupancyTimes"] = try? encoder.encode(occupancyTimes)
    }

}
