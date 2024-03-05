//
//  KalmanFilter.swift
//
//
//  Created by Matt Greenfield on 27/2/24.
//

import Foundation
import CoreLocation
import Surge

internal class KalmanFilter {
    
    private var lastTimestamp: Date?

    // [latitude, longitude, velocity north, velocity east]
    private var stateVector: Matrix<Double> = Matrix([[0], [0], [0], [0]])

    // P
    private var covarianceMatrix: Matrix<Double> = Matrix([
        [0.001, 0, 0, 0],
        [0, 0.001, 0, 0],
        [0, 0, 0.001, 0],
        [0, 0, 0, 0.001]
    ])

    // F
    private var transitionMatrix: Matrix<Double> = Matrix([
        [1, 0, 1, 0],
        [0, 1, 0, 1],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])

    // Q (lower values = higher trust in model prediction)
    private let processNoiseCov = Matrix<Double>([
        [1e-10, 0, 0, 0],
        [0, 1e-10, 0, 0],
        [0, 0, 0.1, 0],
        [0, 0, 0, 0.1]
    ])

    // R (lower values = higher trust in raw data)
    // note: no point in modifying this though - it's only initial state
    private var measurementNoiseCov = Matrix<Double>([
        [1.0, 0, 0, 0],
        [0, 1.0, 0, 0],
        [0, 0, 1.0, 0],
        [0, 0, 0, 1.0]
    ])

    // H
    private let measurementMatrix: Matrix<Double> = Matrix([
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])

    // MARK: -

    func add(location: CLLocation) {
        guard location.coordinate.isUsable else { return }

        print("*** add(location:) ***")

        print(String(
            format: "INPUT     coordinate: %.8f, %.8f; horizontalAccuracy: %.4f, speed: %.4f, course: %.1f, speedAccuracy: %.2f, courseAccuracy: %.2f",
            location.coordinate.latitude,
            location.coordinate.longitude,
            location.horizontalAccuracy,
            location.speed,
            location.course,
            location.speedAccuracy,
            location.courseAccuracy
        ))

        let invalidVelocity = location.invalidVelocity
        let velocityMetresNorth = invalidVelocity ? 0 : location.speed * cos(location.course.radians)
        let velocityMetresEast = invalidVelocity ? 0 : location.speed * sin(location.course.radians)

        let measurement = Matrix<Double>([
            [location.coordinate.latitude],
            [location.coordinate.longitude],
            [degreesLatitude(fromMetresNorth: velocityMetresNorth)],
            [degreesLongitude(fromMetresEast: velocityMetresEast, atLatitude: location.coordinate.latitude)]
        ])

        if let last = lastTimestamp {
            let deltaTime = location.timestamp.timeIntervalSince(last)
            lastTimestamp = location.timestamp

            adjustTransitionMatrix(deltaTime: deltaTime)

            predict()

            let predicted = currentEstimatedLocation()
            print(String(
                format: "PREDICTED coordinate: %.8f, %.8f; horizontalAccuracy: %.4f, speed: %.4f, course: %.1f",
                predicted.coordinate.latitude,
                predicted.coordinate.longitude,
                predicted.horizontalAccuracy,
                predicted.speed,
                predicted.course
            ))

            updateMeasurementNoise(with: location)
            update(measurement: measurement)

        } else {
            stateVector = measurement
            lastTimestamp = location.timestamp
        }

        let result = currentEstimatedLocation()
        print(String(
            format: "RESULT    coordinate: %.8f, %.8f; horizontalAccuracy: %.4f, speed: %.4f, course: %.1f",
            result.coordinate.latitude,
            result.coordinate.longitude,
            result.horizontalAccuracy,
            result.speed,
            result.course
        ))
    }

    func currentEstimatedLocation() -> CLLocation {
        return CLLocation(
            coordinate: currentEstimatedCoordinate(),
            altitude: 0,
            horizontalAccuracy: currentEstimatedHorizontalAccuracy(),
            verticalAccuracy: -1,
            course: currentEstimatedCourse(),
            speed: currentEstimatedSpeed(),
            timestamp: lastTimestamp ?? .now
        )
    }

    func currentEstimatedCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: stateVector[0, 0],
            longitude: stateVector[1, 0]
        )
    }

    func currentEstimatedHorizontalAccuracy() -> CLLocationAccuracy {
        let varianceLatitude = covarianceMatrix[0, 0]
        let varianceLongitude = covarianceMatrix[1, 1]

        // Convert latitude variance directly to meters
        let accuracyLatitudeMeters = sqrt(varianceLatitude) * 111_319.9

        // Adjust longitude variance conversion using latitude
        let metersPerDegreeLongitude = 111_319.9 * cos(stateVector[0, 0].radians)
        let accuracyLongitudeMeters = sqrt(varianceLongitude) * metersPerDegreeLongitude

        return (accuracyLatitudeMeters + accuracyLongitudeMeters) / 2
    }

    func currentEstimatedCourse() -> CLLocationDegrees {
        let velocityNorthDegrees = stateVector[2, 0]
        let velocityEastDegrees = stateVector[3, 0]

        let courseRadians = atan2(velocityEastDegrees, velocityNorthDegrees)
        let courseDegrees = courseRadians * (180 / .pi)

        // Ensure the course is within 0-360 degrees
        return (courseDegrees + 360).truncatingRemainder(dividingBy: 360)
    }

    func currentEstimatedSpeed() -> CLLocationSpeed {
        let latitude = stateVector[0, 0]
        let velocityNorthDegrees = stateVector[2, 0] 
        let velocityEastDegrees = stateVector[3, 0]

        // Convert angular velocity northward to linear velocity (m/s)
        let velocityNorthMeters = velocityNorthDegrees * 111_319.9 

        // Convert angular velocity eastward to linear velocity (m/s), adjusting for latitude
        let metersPerDegreeLongitude = 111_319.9 * cos(latitude.radians) 
        let velocityEastMeters = velocityEastDegrees * metersPerDegreeLongitude

        return sqrt((velocityNorthMeters * velocityNorthMeters) + (velocityEastMeters * velocityEastMeters))
    }


    // MARK: - Private

    func adjustTransitionMatrix(deltaTime: TimeInterval) {
        transitionMatrix[0, 2] = deltaTime
        transitionMatrix[1, 3] = deltaTime
    }

    private func predict() {
        stateVector = transitionMatrix * stateVector
        covarianceMatrix = (transitionMatrix * covarianceMatrix * transpose(transitionMatrix)) + processNoiseCov
    }
    
    private func updateMeasurementNoise(with location: CLLocation) {
        let latitude = location.coordinate.latitude
        let invalidVelocity = location.invalidVelocity

        // sanitise values
        let horizontalAccuracy = max(location.horizontalAccuracy, 1.0)

        // invalidVelocity is encoded as 0 velocities in the measurement
        // so giving that a super high accuracy means it should produce
        // super stable location when indoors (ie when getting -1 speed/course/accuracy)
        let speedAccuracy = invalidVelocity ? 0.01 : max(location.speedAccuracy, 0.01)

        // lat,lon noise
        let hAccuracyDegrees = degrees(fromMetres: horizontalAccuracy, atLatitude: latitude)
        let hAccuracyVariance = hAccuracyDegrees * hAccuracyDegrees
        measurementNoiseCov[0, 0] = hAccuracyVariance
        measurementNoiseCov[1, 1] = hAccuracyVariance

        // velocities noise
        let speedAccuracyDegrees = degrees(fromMetres: speedAccuracy, atLatitude: latitude)
        let speedAccuracyVariance = speedAccuracyDegrees * speedAccuracyDegrees
        measurementNoiseCov[2, 2] = speedAccuracyVariance
        measurementNoiseCov[3, 3] = speedAccuracyVariance
    }

    private func update(measurement: Matrix<Double>) {

        // measurement prediction
        let y = measurement - (measurementMatrix * stateVector)

        // Kalman Gain (K)
        let S = measurementMatrix * covarianceMatrix * transpose(measurementMatrix) + measurementNoiseCov
        let kalmanGain = covarianceMatrix * transpose(measurementMatrix) * inv(S)

        // update the state vector / apply the Kalman
        stateVector = stateVector + (kalmanGain * y)

        // update the covariance matrix
        let identityMatrix = Matrix<Double>.eye(rows: covarianceMatrix.rows, columns: covarianceMatrix.columns)
        covarianceMatrix = (identityMatrix - (kalmanGain * measurementMatrix)) * covarianceMatrix
    }

    // MARK: - Conversions

    func degreesLatitude(fromMetresNorth metresNorth: CLLocationDistance) -> Double {
        let metersPerDegree = 111_319.9
        return metresNorth / metersPerDegree
    }

    func degreesLongitude(fromMetresEast metresEast: CLLocationDistance, atLatitude latitude: CLLocationDegrees) -> Double {
        let metersPerDegree = 111_319.9
        return metresEast / (metersPerDegree * cos(latitude.radians))
    }

    func degrees(fromMetres metres: CLLocationDistance, atLatitude latitude: CLLocationDegrees) -> Double {
        let metersPerDegree = 111_319.9
        let degreesLatitude = metres / metersPerDegree
        let degreesLongitude = metres / (metersPerDegree * cos(latitude.radians))
        return (degreesLatitude + degreesLongitude) / 2
    }

}

extension CLLocation {
    var invalidVelocity: Bool {
        course < 0 || speed < 0 || courseAccuracy < 0 || speedAccuracy < 0
    }
}

extension CLLocationCoordinate2D {
    var isUsable: Bool { !isNullIsland && isValid }
    var isNullIsland: Bool { latitude == 0 && longitude == 0 }
    var isValid: Bool { CLLocationCoordinate2DIsValid(self) }
}
