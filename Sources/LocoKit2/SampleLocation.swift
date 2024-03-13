//
//  SampleLocation.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct SampleLocation: Codable, FetchableRecord, PersistableRecord {
    let sampleId: String
    let timestamp: Date
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let altitude: CLLocationDistance
    let horizontalAccuracy: CLLocationAccuracy
    let verticalAccuracy: CLLocationAccuracy
    let speed: CLLocationSpeed
    let course: CLLocationDirection

    static let base = belongsTo(SampleBase.self, key: "sampleId")

    init(sampleId: String, location: CLLocation) {
        self.sampleId = sampleId
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
    }

    // MARK: -

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        return CLLocation(
            coordinate: coordinate, altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course, speed: speed,
            timestamp: timestamp
        )
    }

}
