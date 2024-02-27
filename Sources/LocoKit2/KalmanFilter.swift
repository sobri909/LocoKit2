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

    // State vector: [latitude, longitude, velocity north, velocity east]
    private var stateVector: Matrix<Double> = Matrix([[0], [0], [0], [0]])

    private let transitionMatrix: Matrix<Double>
    private var covarianceMatrix: Matrix<Double>
    private let measurementNoiseCov: Matrix<Double>
    private let processNoiseCov: Matrix<Double>
    private let measurementMatrix: Matrix<Double>

    init() {
        // Initialize matrices here
        // Placeholder values for illustration; adjust based on your system's dynamics
        transitionMatrix = Matrix(
            [
                [1, 0, 1, 0],
                [0, 1, 0, 1],
                [0, 0, 1, 0],
                [0, 0, 0, 1]
            ]
        )
        covarianceMatrix = Matrix(repeating: 0.0, rows: 4, columns: 4)
        
        // Customize based on measurement accuracy
        measurementNoiseCov = Matrix(repeating: 1.0, rows: 4, columns: 4)
        
        // Adjust based on process noise estimation
        processNoiseCov = Matrix(repeating: 0.1, rows: 4, columns: 4)
        
        measurementMatrix = Matrix(
            [
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0, 0, 0, 1]
            ]
        ) // Adjust as necessary
    }

    // MARK: -

    func add(location: CLLocation) {
        // Convert CLLocation to measurement matrix
        let measurement = Matrix([
            [location.coordinate.latitude],
            [location.coordinate.longitude],
            [location.speed * cos(location.course.radians)],
            [location.speed * sin(location.course.radians)]
        ])

        // Predict step
        predict()

        // Update step with the new measurement
        update(measurement: measurement)
    }

    private func predict() {
        // Predict the state
        stateVector = Surge.mul(transitionMatrix, stateVector)
        // Predict the covariance
        let transposedF = Surge.transpose(transitionMatrix)
        covarianceMatrix = Surge.mul(Surge.mul(transitionMatrix, covarianceMatrix), transposedF) + processNoiseCov
    }

    private func update(measurement: Matrix<Double>) {
        // Implementation of the update step
        // This includes calculating the Kalman Gain, updating the stateVector, and updating the covarianceMatrix
        // Similar structure to the previously provided update function
    }

    func predictedCurrentValues() -> (latitude: Double, longitude: Double, velocityNorth: Double, velocityEast: Double) {
        // Return the current values of the state vector
        return (stateVector[0, 0], stateVector[1, 0], stateVector[2, 0], stateVector[3, 0])
    }

}
