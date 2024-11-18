//
//  Place.swift
//
//
//  Created by Matt Greenfield on 25/3/24.
//

import Foundation
import CoreLocation
@preconcurrency import GRDB

public enum PlaceSource { case google, foursquare, mapbox }

public struct Place: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public static let minimumPlaceRadius: CLLocationDistance = 8
    public static let maximumPlaceRadius: CLLocationDistance = 2000
    public static let minimumNewPlaceRadius: CLLocationDistance = 60

    public var id: String = UUID().uuidString
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

    // MARK: - Overlaps etc

    public func contains(_ location: CLLocation, sd: Double) -> Bool {
        return location.distance(from: center.location) <= radius.withSD(sd)
    }

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

    // MARK: - Timezone

    public var localTimeZone: TimeZone? {
        guard let secondsFromGMT else { return nil }
        return TimeZone(secondsFromGMT: secondsFromGMT)
    }

    @PlacesActor
    public mutating func fetchLocalTimezone() async {
        if secondsFromGMT != nil { return }

        do {
            guard let timeZone = try await CLGeocoder().reverseGeocodeLocation(center.location).first?.timeZone else {
                return
            }

            do {
                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.secondsFromGMT = timeZone.secondsFromGMT()
                    }
                }
                self.secondsFromGMT = timeZone.secondsFromGMT()

            } catch {
                logger.error(error, subsystem: .database)
            }

        } catch {
            logger.error(error, subsystem: .places)
        }
    }

    // MARK: - Stats

    @PlacesActor
    public mutating func updateVisitStats() async {
        do {
            let visits = try await Database.pool.read { [id] db in
                try TimelineItem
                    .itemRequest(includeSamples: true, includePlaces: true)
                    .filter(sql: "visit.placeId = ?", arguments: [id])
                    .filter(Column("deleted") == false)
                    .fetchAll(db)
            }

            if visits.isEmpty {
                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = 0
                        $0.visitDays = 0
                        $0.isStale = false
                    }
                }
                return
            }

            // count unique visit days using place's timezone
            var calendar = Calendar.current
            calendar.timeZone = localTimeZone ?? .current

            let uniqueDays = Set<Date>(visits.compactMap {
                return $0.dateRange?.start.startOfDay(in: calendar)
            })

            let confirmedVisits = visits.filter { $0.visit?.confirmedPlace == true }
            let samples = confirmedVisits.flatMap { $0.samples ?? [] }

            // Only update if we have valid data to update with
            if let center = samples.weightedCenter() {
                let radius = samples.radius(from: center.location)

                let boundedMean = radius.mean.clamped(min: Place.minimumPlaceRadius, max: Place.maximumPlaceRadius)
                let boundedSD = radius.sd.clamped(min: 0, max: Place.maximumPlaceRadius)

                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = visits.count
                        $0.visitDays = uniqueDays.count
                        $0.latitude = center.latitude
                        $0.longitude = center.longitude
                        $0.radiusMean = boundedMean
                        $0.radiusSD = boundedSD
                        $0.isStale = false
                    }
                }
            }

            // keep histogram updates until we persist them
            let visitStarts = confirmedVisits.compactMap { $0.dateRange?.start }
            let visitEnds = confirmedVisits.compactMap { $0.dateRange?.end }
            let visitDurations = confirmedVisits.compactMap { $0.dateRange?.duration }

            self.arrivalTimes = Histogram.forTimeOfDay(dates: visitStarts, timeZone: localTimeZone ?? .current)
            self.leavingTimes = Histogram.forTimeOfDay(dates: visitEnds, timeZone: localTimeZone ?? .current)
            self.visitDurations = Histogram.forDurations(intervals: visitDurations)

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - RTree

    public mutating func updateRTree() async {
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
                rtreeId = try await Database.pool.write { [self] db in
                    var rtree = PlaceRTree(
                        latMin: center.latitude, latMax: center.latitude,
                        lonMin: center.longitude, lonMax: center.longitude
                    )
                    try rtree.insert(db)

                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.rtreeId = rtree.id
                    }
                    return rtree.id
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

}
