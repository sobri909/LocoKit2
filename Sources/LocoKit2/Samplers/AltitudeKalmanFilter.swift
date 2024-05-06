//
//  AltitudeKalmanFilter.swift
//
//
//  Created by Matt Greenfield on 29/05/17.
//

import CoreLocation

// source: https://stackoverflow.com/a/15657798/790036

internal class AltitudeKalmanFilter {

    private var q: Double // expected mps change per sample
    private var k: Double = 1 // trust to apply to new values
    private var variance: Double = -1 // p "matrix"
    private var timestamp: TimeInterval = 0

    public private(set) var altitude: Double?
    public private(set) var unfilteredLocation: CLLocation?

    public init(qMetresPerSecond: Double) {
        self.q = qMetresPerSecond
    }

    // MARK: -

    public func add(location: CLLocation) {
        guard location.verticalAccuracy > 0 else { return }
        guard location.timestamp.timeIntervalSince1970 >= timestamp else { return }

        unfilteredLocation = location

        // update the kalman internals
        update(date: location.timestamp, accuracy: location.verticalAccuracy)

        // apply the k
        if let oldAltitude = altitude {
            self.altitude = oldAltitude + (k * (location.altitude - oldAltitude))
        } else {
            self.altitude = location.altitude
        }
    }

    // next input will be treated as first
    public func reset() {
        k = 1
        variance = -1
        altitude = nil
    }

    public func resetVarianceTo(accuracy: Double) {
        variance = accuracy * accuracy
    }

    public var accuracy: Double {
        return variance.squareRoot()
    }
    
    public var date: Date {
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Private

    private func update(date: Date, accuracy: Double) {

        // first input after init or reset
        if variance < 0 {
            variance = accuracy * accuracy
            timestamp = date.timeIntervalSince1970
            return
        }

        // uncertainty in the current value increases as time passes
        let timeDiff = date.timeIntervalSince1970 - timestamp
        if timeDiff > 0 {
            variance += timeDiff * q * q
            timestamp = date.timeIntervalSince1970
        }

        // gain matrix k = covariance * inverse(covariance + measurementVariance)
        k = variance / (variance + accuracy * accuracy)

        // new covariance matrix is (identityMatrix - k) * covariance
        variance = (1.0 - k) * variance
    }

}
