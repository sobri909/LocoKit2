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

public extension CLLocation {
    convenience init(from codable: CodableLocation) {
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

    var codable: CodableLocation {
        return CodableLocation(self)
    }

    var invalidVelocity: Bool {
        course < 0 || speed < 0 || courseAccuracy < 0 || speedAccuracy < 0
    }
}

public extension CLLocationCoordinate2D {
    var isUsable: Bool { !isNullIsland && isValid }
    var isNullIsland: Bool { latitude == 0 && longitude == 0 }
    var isValid: Bool { CLLocationCoordinate2DIsValid(self) }
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

    func usableLocations() -> [CLLocation] {
        return compactMap { $0.coordinate.isUsable ? $0 : nil }
    }

    func distance() -> CLLocationDistance? {
        let usableLocations = self.usableLocations()

        if usableLocations.isEmpty {
            return nil
        }

        if usableLocations.count == 1 {
            return 0
        }

        var totalDistance: CLLocationDistance = 0
        for index in 1..<usableLocations.count {
            let previous = usableLocations[index - 1]
            let current = usableLocations[index]
            totalDistance += current.distance(from: previous)
        }

        return totalDistance
    }

    func weightedCenter() -> CLLocationCoordinate2D? {
        let usableLocations = self.usableLocations()

        if usableLocations.isEmpty {
            return nil
        }
        
        if usableLocations.count == 1 {
            return usableLocations.first?.coordinate
        }

        var sumX: Double = 0
        var sumY: Double = 0
        var sumZ: Double = 0
        var totalWeight: Double = 0

        for location in usableLocations {
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

    func radius(from center: CLLocation) -> Radius {
        let usableLocations = self.usableLocations()

        if usableLocations.isEmpty {
            return .zero
        }
        
        if usableLocations.count == 1 {
            if let accuracy = usableLocations.first?.horizontalAccuracy, accuracy >= 0 {
                return Radius(mean: accuracy, sd: 0)
            }
            return .zero
        }

        let distances = usableLocations.map { $0.distance(from: center) }
        return Radius(mean: distances.mean(), sd: distances.standardDeviation())
    }

}
