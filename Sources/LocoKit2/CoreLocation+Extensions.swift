//
//  Created by Matt Greenfield on 27/2/24.
//

import Foundation
import CoreLocation

typealias Radians = Double

extension Radians {
    var degrees: CLLocationDegrees { self * 180.0 / .pi }
}

extension CLLocationDegrees {
    var radians: Radians { self * .pi / 180.0 }
}

extension CLLocation {
    public convenience init(from codable: CodableLocation) {
        self.init(
            coordinate: CLLocationCoordinate2D(latitude: codable.latitude, longitude: codable.longitude),
            altitude: codable.altitude,
            horizontalAccuracy: codable.horizontalAccuracy,
            verticalAccuracy: codable.verticalAccuracy,
            course: codable.course, 
            speed: codable.speed,
            timestamp: codable.timestamp
        )
    }

    public var codable: CodableLocation {
        return CodableLocation(self)
    }
}

public struct CodableLocation: Codable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let altitude: CLLocationDistance
    let horizontalAccuracy: CLLocationAccuracy
    let verticalAccuracy: CLLocationAccuracy
    let speed: CLLocationSpeed
    let course: CLLocationDirection
    let timestamp: Date

    init(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
        self.timestamp = location.timestamp
    }
}

public extension Array where Element: CLLocation {
    func weightedCenter() -> CLLocationCoordinate2D? {
        if self.isEmpty { return nil }
        if self.count == 1 { return first?.coordinate }

        var sumX: Double = 0
        var sumY: Double = 0
        var sumZ: Double = 0
        var totalWeight: Double = 0

        for location in self {
            let latitude = location.coordinate.latitude.radians
            let longitude = location.coordinate.longitude.radians
            let weight = 1 / (location.horizontalAccuracy * location.horizontalAccuracy)

            let cosLatitude = cos(latitude)
            let sinLatitude = sin(latitude)
            let cosLongitude = cos(longitude)
            let sinLongitude = sin(longitude)

            sumX += cosLatitude * cosLongitude * weight
            sumY += cosLatitude * sinLongitude * weight
            sumZ += sinLatitude * weight
            totalWeight += weight
        }

        let averageX = sumX / totalWeight
        let averageY = sumY / totalWeight
        let averageZ = sumZ / totalWeight

        let averageLatitude = atan2(averageZ, sqrt(averageX * averageX + averageY * averageY)).degrees
        let averageLongitude = atan2(averageY, averageX).degrees

        return CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)
    }
}
