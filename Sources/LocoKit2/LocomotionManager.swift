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

}
