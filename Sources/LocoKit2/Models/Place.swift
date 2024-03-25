//
//  Place.swift
//
//
//  Created by Matt Greenfield on 25/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class Place: Record, Identifiable, Codable {
    public var id: String = UUID().uuidString
    public var isStale = false
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var radiusMean: CLLocationDistance
    public var radiusSD: CLLocationDistance

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var radius: Radius {
        Radius(mean: radiusMean, sd: radiusSD)
    }

    // MARK: - Record

    required init(row: Row) throws {
        id = row["id"]
        isStale = row["isStale"]
        latitude = row["latitude"]
        longitude = row["longitude"]
        radiusMean = row["radiusMean"]
        radiusSD = row["radiusSD"]
        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["isStale"] = isStale
        container["latitude"] = latitude
        container["longitude"] = longitude
        container["radiusMean"] = radiusMean
        container["radiusSD"] = radiusSD
    }
}
