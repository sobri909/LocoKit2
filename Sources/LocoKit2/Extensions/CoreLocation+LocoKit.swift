//
//  Created by Matt Greenfield on 27/2/24.
//

import Foundation
import CoreLocation
import CoreMotion
import simd

public typealias Radians = Double

public extension Radians {
    var degrees: CLLocationDegrees { self * 180.0 / .pi }
}

public extension CLLocationDegrees {
    var radians: Radians { self * .pi / 180.0 }
}

extension CLLocationSpeed {
    init(kmh: Double) { self.init(kmh / 3.6) }
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

    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var codable: CodableLocation {
        return CodableLocation(self)
    }

    var invalidVelocity: Bool {
        course < 0 || speed < 0 || courseAccuracy < 0 || speedAccuracy < 0
    }

    var hasUsableCoordinate: Bool {
        horizontalAccuracy >= 0 && coordinate.isUsable
    }
}

public extension CLLocationCoordinate2D {
    var isUsable: Bool { !isNullIsland && isValid }
    var isNullIsland: Bool { latitude == 0 && longitude == 0 }
    var isValid: Bool { CLLocationCoordinate2DIsValid(self) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    func perpendicularDistance(to line: (CLLocationCoordinate2D, CLLocationCoordinate2D)) -> CLLocationDistance {
        let lat = self.latitude.radians
        let lon = self.longitude.radians
        let lat1 = line.0.latitude.radians
        let lon1 = line.0.longitude.radians
        let lat2 = line.1.latitude.radians
        let lon2 = line.1.longitude.radians

        let earthRadius: CLLocationDistance = 6371000

        // Initial bearing from start to end
        let theta12 = atan2(
            sin(lon2 - lon1) * cos(lat2),
            cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
        )

        let theta13 = atan2(
            sin(lon - lon1) * cos(lat),
            cos(lat1) * sin(lat) - sin(lat1) * cos(lat) * cos(lon - lon1)
        )

        // Angular distances
        let delta13 = acos(sin(lat1) * sin(lat) + cos(lat1) * cos(lat) * cos(lon - lon1))
        let delta12 = acos(sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1))

        // Cross-track distance
        let crossTrackAngle = asin(sin(delta13) * sin(theta13 - theta12))
        let crossTrackDistance = abs(earthRadius * crossTrackAngle)

        // Along-track distance to the foot of the perpendicular
        let alongTrackAngle = acos(cos(delta13) / cos(crossTrackAngle))
        let alongTrackDistance = alongTrackAngle * earthRadius

        let totalDistance = delta12 * earthRadius

        if alongTrackDistance < 0 {
            // The perpendicular foot falls before the start point
            let distanceToStart = delta13 * earthRadius
            return distanceToStart
        } else if alongTrackDistance > totalDistance {
            // The perpendicular foot falls beyond the end point
            let delta23 = acos(sin(lat2) * sin(lat) + cos(lat2) * cos(lat) * cos(lon - lon2))
            let distanceToEnd = delta23 * earthRadius
            return distanceToEnd
        } else {
            // The perpendicular foot falls within the segment
            return crossTrackDistance
        }
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

// MARK: - Core Motion

// source: http://stackoverflow.com/a/8006783/790036
extension CMDeviceMotion {
    var userAccelerationInReferenceFrame: CMAcceleration {
        let acc = simd_double3(userAcceleration.x, userAcceleration.y, userAcceleration.z)
        let rot = simd_double3x3(
            simd_double3(attitude.rotationMatrix.m11, attitude.rotationMatrix.m21, attitude.rotationMatrix.m31),
            simd_double3(attitude.rotationMatrix.m12, attitude.rotationMatrix.m22, attitude.rotationMatrix.m32),
            simd_double3(attitude.rotationMatrix.m13, attitude.rotationMatrix.m23, attitude.rotationMatrix.m33)
        )
        let result = rot * acc
        return CMAcceleration(x: result.x, y: result.y, z: result.z)
    }
}
