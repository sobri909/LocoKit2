//
//  TimelineItemVisit.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class TimelineItemVisit: Record, Codable {

    public static var minRadius: CLLocationDistance = 10
    public static var maxRadius: CLLocationDistance = 150

    public let itemId: String
    public var isStale = false
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance
    public var radiusSD: CLLocationDistance

    public var placeId: String?
    public var confirmedPlace = false

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var radius: Radius {
        Radius(mean: radiusMean, sd: radiusSD)
    }

    public override class var databaseTableName: String { return "TimelineItemVisit" }

    // MARK: -

    public func update(from samples: [LocomotionSample]) {
        let usableLocations = samples.compactMap { $0.location }.usableLocations()

        guard let coordinate = usableLocations.weightedCenter() else {
            return
        }

        self.isStale = false
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let radius = usableLocations.radius(from: center)
        self.radiusMean = min(max(radius.mean, Self.minRadius), Self.maxRadius)
        self.radiusSD = min(radius.sd, Self.maxRadius)
    }

    // MARK: - Init

    init?(itemId: String, samples: [LocomotionSample]) {
        let usableLocations = samples.compactMap { $0.location }.usableLocations()

        guard let coordinate = usableLocations.weightedCenter() else {
            return nil
        }

        self.itemId = itemId
        self.isStale = false
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let radius = usableLocations.radius(from: center)
        self.radiusMean = min(max(radius.mean, Self.minRadius), Self.maxRadius)
        self.radiusSD = min(radius.sd, Self.maxRadius)

        super.init()
    }
    
    // MARK: - Record

    required init(row: Row) throws {
        itemId = row["itemId"]
        isStale = row["isStale"]
        latitude = row["latitude"]
        longitude = row["longitude"]
        radiusMean = row["radiusMean"]
        radiusSD = row["radiusSD"]
        placeId = row["placeId"]
        confirmedPlace = row["confirmedPlace"]
        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["itemId"] = itemId
        container["isStale"] = isStale
        container["latitude"] = latitude
        container["longitude"] = longitude
        container["radiusMean"] = radiusMean
        container["radiusSD"] = radiusSD
        container["placeId"] = placeId
        container["confirmedPlace"] = confirmedPlace
    }

}
