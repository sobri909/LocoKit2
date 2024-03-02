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
        [0.0001, 0, 0, 0],
        [0, 0.0001, 0, 0],
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

        let invalidVelocity = location.course < 0 || location.speed < 0
        let msVelNorth = invalidVelocity ? 0 : location.speed * cos(location.course.radians)
        let msVelEast = invalidVelocity ? 0 : location.speed * sin(location.course.radians)

        let measurement = Matrix<Double>([
            [location.coordinate.latitude],
            [location.coordinate.longitude],
            [velocityToLatitudeChangePerSecond(velocity: msVelNorth)],
            [velocityToLongitudeChangePerSecond(velocity: msVelEast, atLatitude: location.coordinate.latitude)]
        ])

        print("measurement:\n", measurement)

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
        // TODO: should capture negative accuracy values and change them to something awful and high

        let horizontalAccuracy = max(location.horizontalAccuracy, 1.0)
        let speedAccuracy = location.speedAccuracy >= 0 ? max(location.speedAccuracy, 0.1) : 100.0
        let latitude = location.coordinate.latitude

        let accuracyDegrees = accuracyToDegrees(accuracy: horizontalAccuracy, atLatitude: latitude)
        let accuracyVariance = accuracyDegrees * accuracyDegrees
        measurementNoiseCov[0, 0] = accuracyVariance
        measurementNoiseCov[1, 1] = accuracyVariance

        let speedAccuracyDps = convertSpeedAccuracyToDegreesPerSecond(speedAccuracy: speedAccuracy, atLatitude: latitude)
        let speedAccuracyVariance = speedAccuracyDps * speedAccuracyDps
        measurementNoiseCov[2, 2] = speedAccuracyVariance
        measurementNoiseCov[3, 3] = speedAccuracyVariance
    }

    private func update(measurement: Matrix<Double>) {

        // Calculate the measurement prediction
        let y = measurement - (measurementMatrix * stateVector)

        print("y:\n", y)

        // Calculate the Kalman Gain (K)
        let S = measurementMatrix * covarianceMatrix * transpose(measurementMatrix) + measurementNoiseCov
        let kalmanGain = covarianceMatrix * transpose(measurementMatrix) * inv(S)

        let push = kalmanGain * y
        let latDiff = abs(y[0,0] - push[0,0])
        let lonDiff = abs(y[1,0] - push[1,0])
        print("kalmanGain:\n", kalmanGain)
        print("kalmanGain * y:\n", kalmanGain * y)
        print(String(format: "latDiff: %.8f, lonDiff: %.8f", latDiff, lonDiff))

        // Update the state vector with the new measurement
        stateVector = stateVector + (kalmanGain * y)

        // Update the covariance matrix
        let identityMatrix = Matrix<Double>.eye(rows: covarianceMatrix.rows, columns: covarianceMatrix.columns)
        covarianceMatrix = (identityMatrix - (kalmanGain * measurementMatrix)) * covarianceMatrix
    }

    // MARK: - Conversions

    func velocityToLatitudeChangePerSecond(velocity: CLLocationSpeed) -> Double {
        let metersPerDegree = 111_320.0
        return velocity / metersPerDegree
    }

    func velocityToLongitudeChangePerSecond(velocity: CLLocationSpeed, atLatitude latitude: CLLocationDegrees) -> Double {
        let metersPerDegreeAtEquator = 111_320.0
        let adjustmentFactor = cos(latitude.radians)
        return velocity / (metersPerDegreeAtEquator * adjustmentFactor)
    }

    func accuracyToDegrees(accuracy: CLLocationAccuracy, atLatitude latitude: CLLocationDegrees) -> Double {
        // Convert the accuracy radius from meters to degrees of latitude
        let degreesLat = (accuracy / 111_319.9) * (180 / .pi)

        // Convert the accuracy radius from meters to degrees of longitude, adjusted for latitude
        let earthRadiusMetres = 111_319.9 * cos(latitude.radians)
        let degreesLon = (accuracy / earthRadiusMetres) * (180 / .pi)

        // Return the average of the latitude and longitude degrees
        return (degreesLat + degreesLon) / 2
    }

    func convertSpeedAccuracyToDegreesPerSecond(speedAccuracy: CLLocationSpeed, atLatitude latitude: CLLocationDegrees) -> Double {
        // Earth's radius in metres at the equator
        let earthRadiusMetres = 111_319.9

        // Convert speed accuracy from m/s to degrees per second for latitude
        // For latitude, we can use the Earth's radius directly because 1 degree of latitude is approximately the same distance anywhere on Earth
        let speedAccuracyDegreesLatitude = speedAccuracy / earthRadiusMetres

        // For longitude, we need to adjust based on the latitude because 1 degree of longitude varies in distance
        let speedAccuracyDegreesLongitude = speedAccuracy / (earthRadiusMetres * cos(latitude.radians))

        // You might choose to use the larger of the two values to ensure the variance covers the worst-case scenario
        // Alternatively, you could average them, but using the larger value is a conservative approach
        let speedAccuracyDegreesPerSecond = max(speedAccuracyDegreesLatitude, speedAccuracyDegreesLongitude)

        return speedAccuracyDegreesPerSecond
    }

}
