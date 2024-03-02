//
//  LocomotionManager.swift
//
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import Observation
import CoreLocation

@Observable
public final class LocomotionManager {

    public static let highlander = LocomotionManager()

    private let activityBrain = ActivityBrain()

    // MARK: - Public
    
    public private(set) var recordingState: RecordingState = .off
    public internal(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    public var rawLocations: [CLLocation] = []
    public var oldKLocations: [CLLocation] = []
    public var newKLocations: [CLLocation] = []

    // MARK: -
    
    public func startRecording() {
        print("LocomotionManager.startRecording()")

        // start updating locations
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges() // is it allowed to start both?

        recordingState = .recording
    }

    public func requestAuthorization() {
        print("LocomotionManager.requestAuthorization()")
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Private
    
    private func startSleeping() {
        print("LocomotionManager.startSleeping()")
        
        // note: need to call start because might be coming from off state
        // or might be coming from locationManagerDidPauseLocationUpdates()
        locationManager.distanceFilter = kCLLocationAccuracyThreeKilometers
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges() // is it allowed to start both?

        recordingState = .sleeping
    }

    // MARK: -

    private init() {}

    @ObservationIgnored
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = kCLDistanceFilterNone
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = true // EXPERIMENTAL
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true
        manager.delegate = self.locationDelegate
        return manager
    }()
    
    @ObservationIgnored
    private lazy var locationDelegate = {
        return Delegate(parent: self)
    }()

    func add(location: CLLocation) {
//        if !rawLocations.isEmpty { return }

        reallyAdd(location: location)

        return

        let simulated1 = simulated(from: location, displacementMeters: 10, displacementCourse: 0, elapsedTime: 1, course: 0, horizontalAccuracy: 10, speedAccuracy: 10)
        reallyAdd(location: simulated1)

        let simulated2 = simulated(from: simulated1, displacementMeters: 10, displacementCourse: 90, elapsedTime: 1, course: 90, horizontalAccuracy: 10, speedAccuracy: 100)
        reallyAdd(location: simulated2)

        let simulated3 = simulated(from: simulated2, displacementMeters: 10, displacementCourse: 0, elapsedTime: 1, course: 0, horizontalAccuracy: 10, speedAccuracy: 100)
        reallyAdd(location: simulated3)

        let simulated4 = simulated(from: simulated3, displacementMeters: 10, displacementCourse: 90, elapsedTime: 1, course: 90, horizontalAccuracy: 10, speedAccuracy: 100)
        reallyAdd(location: simulated4)

        let simulated5 = simulated(from: simulated4, displacementMeters: 10, displacementCourse: 0, elapsedTime: 1, course: 0, horizontalAccuracy: 10, speedAccuracy: 100)
        reallyAdd(location: simulated5)

        let simulated6 = simulated(from: simulated5, displacementMeters: 10, displacementCourse: 90, elapsedTime: 1, course: 90, horizontalAccuracy: 10, speedAccuracy: 100)
        reallyAdd(location: simulated6)
    }
    
    func reallyAdd(location: CLLocation) {
        rawLocations.append(location)
        activityBrain.add(location: location)
        newKLocations.append(activityBrain.newKalman.currentEstimatedLocation())
        if let coord = activityBrain.oldKalman.coordinate {
            oldKLocations.append(CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
    }

    // MARK: - CLLocationManagerDelegate

    private class Delegate: NSObject, CLLocationManagerDelegate {
        let parent: LocomotionManager

        init(parent: LocomotionManager) {
            self.parent = parent
            super.init()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//            print("CLLocationManagerDelegate.didUpdateLocations() locations: \(locations.count)")
            for location in locations {
                parent.add(location: location)
            }
        }

        func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
            print("CLLocationManagerDelegate.locationManagerDidPauseLocationUpdates()")
            parent.startSleeping()
        }

        func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
            print("CLLocationManagerDelegate.locationManagerDidResumeLocationUpdates()")
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            print("CLLocationManagerDelegate.locationManagerDidChangeAuthorization() authorizationStatus: \(manager.authorizationStatus)")
            parent.authorizationStatus = manager.authorizationStatus
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("CLLocationManagerDelegate.didFailWithError(): \(error)")
        }
    }

    func simulated(
        from initialLocation: CLLocation,
        displacementMeters: Double,
        displacementCourse: CLLocationDirection,
        elapsedTime: TimeInterval, // Added parameter for explicit control over time delta
        speed: CLLocationSpeed? = nil, // nil to calculate based on displacement and elapsedTime
        course: CLLocationDirection? = nil, // nil to use displacementCourse
        horizontalAccuracy: CLLocationAccuracy = 10,
        speedAccuracy: CLLocationAccuracy? = nil
    ) -> CLLocation {

        // Calculate the new latitude and longitude based on the displacement and course
        let bearingRadians = displacementCourse * .pi / 180.0
        let distanceRadians = displacementMeters / 6372797.6 // Earth's radius in meters
        let initialLatRadians = initialLocation.coordinate.latitude * .pi / 180.0
        let initialLonRadians = initialLocation.coordinate.longitude * .pi / 180.0

        let newLatRadians = asin(
            sin(initialLatRadians) * cos(distanceRadians) +
            cos(initialLatRadians) * sin(distanceRadians) * cos(bearingRadians)
        )
        let newLonRadians = initialLonRadians + atan2(
            sin(bearingRadians) * sin(distanceRadians) * cos(initialLatRadians),
            cos(distanceRadians) - sin(initialLatRadians) * sin(newLatRadians)
        )

        let newLatitude = newLatRadians * 180.0 / .pi
        let newLongitude = newLonRadians * 180.0 / .pi

        // Calculate speed based on displacement and elapsedTime if not provided
        let calculatedSpeed = speed ?? (displacementMeters / elapsedTime)

        // Set default speed accuracy if not provided
        let finalSpeedAccuracy = speedAccuracy ?? 1.0 // Assuming a default speed accuracy if not specified

        // Create the new CLLocation
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude),
            altitude: initialLocation.altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: initialLocation.verticalAccuracy,
            course: course ?? displacementCourse,
            courseAccuracy: course != nil ? 0 : 5, // Assuming a default course accuracy
            speed: calculatedSpeed,
            speedAccuracy: finalSpeedAccuracy,
            timestamp: initialLocation.timestamp + elapsedTime
        )

        return newLocation
    }

}
