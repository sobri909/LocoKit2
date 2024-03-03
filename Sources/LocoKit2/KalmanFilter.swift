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

    // State vector: [latitude, longitude, velocity north, velocity east]
    private var stateVector: Matrix<Double> = Matrix([[0], [0], [0], [0]])

    // P
    private var covarianceMatrix: Matrix<Double> = Matrix(rows: 4, columns: 4, repeatedValue: 0.0)

    // F
    private var transitionMatrix: Matrix<Double> = Matrix([
        [1, 0, 1, 0],
        [0, 1, 0, 1],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])

    // Q (lower values = higher trust in model prediction)
    private let processNoiseCov = Matrix<Double>([
        [1e-9, 0, 0, 0],
        [0, 1e-9, 0, 0],
        [0, 0, 0.0001, 0],
        [0, 0, 0, 0.0001]
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
        // TODO: reject locations with bogus coordinates
        
        print(String(format: "INPUT     coordinate: %.8f, %.8f; horizontalAccuracy: \(location.horizontalAccuracy), speed: \(location.speed), course: \(location.course), speedAccuracy: \(location.speedAccuracy), courseAccuracy: \(location.courseAccuracy)",
              location.coordinate.latitude, location.coordinate.longitude))

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

            print(String(format: "PREDICTED coordinate: %.8f, %.8f", stateVector[0, 0], stateVector[1, 0]))

            updateMeasurementNoise(with: location)
            update(measurement: measurement)

        } else {
            stateVector = measurement
            lastTimestamp = location.timestamp
        }

        print(String(format: "RESULT    coordinate: %.8f, %.8f", stateVector[0, 0], stateVector[1, 0]))
    }

    func currentEstimatedLocation() -> CLLocation {
        // Extract the estimated latitude, longitude, velocityNorth, and velocityEast from the state vector
        let latitude = stateVector[0, 0]
        let longitude = stateVector[1, 0]
        let velocityNorth = stateVector[2, 0]
        let velocityEast = stateVector[3, 0]

        // Calculate the overall speed and course from velocityNorth and velocityEast
        let speed = sqrt((velocityNorth * velocityNorth) + (velocityEast * velocityEast)) // Pythagorean theorem
        let course = atan2(velocityEast, velocityNorth) * (180 / .pi) // Convert radians to degrees

        // Create a new CLLocation object with the estimated state
        let estimatedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0,
            course: course, speed: speed,
            timestamp: lastTimestamp ?? .now
        )

        return estimatedLocation
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
        let speedAccuracy = invalidVelocity ? 1.0 : max(location.speedAccuracy, 0.1)

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
