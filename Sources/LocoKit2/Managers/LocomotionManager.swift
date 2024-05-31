//
//  LocomotionManager.swift
//
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import Observation
import CoreLocation
import CoreMotion

@Observable
public final class LocomotionManager {

    public static let highlander = LocomotionManager()

    // MARK: - Public
    
    public var sleepCycleDuration: TimeInterval = 30
    public var standbyCycleDuration: TimeInterval = 60 * 2
    public var fallbackUpdateDuration: TimeInterval = 6

    public var appGroup: AppGroup?
    public var appGroupOld: AppGroupOld?

    public private(set) var recordingState: RecordingState = .off {
        didSet { appGroup?.save() }
    }
    public internal(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    public internal(set) var motionAuthorizationStatus: CMAuthorizationStatus = {
        CMMotionActivityManager.authorizationStatus()
    }()

    public private(set) var lastUpdated: Date?
    public private(set) var lastRawLocation: CLLocation?
    public private(set) var lastFilteredLocation: CLLocation?

    // MARK: - Recording states

    public func startRecording() {
        DebugLogger.logger.info("LocomotionManager.startRecording()")

        backgroundSession = CLBackgroundActivitySession()

        recordingState = .recording

        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        sleepLocationManager.stopUpdatingLocation()

        startCoreMotion()

        restartTheFallbackTimer()
    }

    public func stopRecording() {
        DebugLogger.logger.info("LocomotionManager.stopRecording()")

        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        sleepLocationManager.stopUpdatingLocation()

        stopCoreMotion()

        stopTheFallbackTimer()
        stopTheWakeupTimer()

        backgroundSession?.invalidate()
        backgroundSession = nil

        recordingState = .off
    }

    public func startStandby() {
        sleepLocationManager.startUpdatingLocation()
        sleepLocationManager.startMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()

        stopCoreMotion()

        // no fallback updates while in standby
        stopTheFallbackTimer()

        // reset the standby timer
        restartTheStandbyTimer()

        recordingState = .standby
    }

    // MARK: - Authorisation

    public func requestLocationAuthorization() {
        DebugLogger.logger.info("LocomotionManager.requestLocationAuthorization()")
        locationManager.requestAlwaysAuthorization()
    }

    public func requestMotionAuthorization() async {
        DebugLogger.logger.info("LocomotionManager.requestMotionAuthorization()")
        await withCheckedContinuation { continuation in
            motionAuthPedometer.queryPedometerData(from: .now - .hours(1), to: .now) { data, error in
                if let error { DebugLogger.logger.error(error, subsystem: .misc) }
                self.motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
                self.motionAuthPedometer.stopUpdates()
                continuation.resume()
            }
        }
    }

    private let motionAuthPedometer = CMPedometer()

    // MARK: - Recorded data

    public func createASample() async -> LocomotionSample {
        let location = await kalmanFilter.currentEstimatedLocation()
        let movingState = await stationaryDetector.currentState()
        let stepHz = await stepsSampler.currentStepHz()

        var sample = LocomotionSample(
            date: location.timestamp,
            movingState: movingState.movingState,
            recordingState: recordingState,
            location: location
        )
        sample.stepHz = stepHz

        if let wiggles = accelerometerSampler.currentAccelerationData() {
            sample.xyAcceleration = wiggles.xyMean + (wiggles.xySD * 3)
            sample.zAcceleration = wiggles.zMean + (wiggles.zSD * 3)
        }

        return sample
    }

    public func createALegacySample() async -> LegacySample {
        let location = await kalmanFilter.currentEstimatedLocation()
        let movingState = await stationaryDetector.currentState()
        let stepHz = await stepsSampler.currentStepHz()

        let sample = LegacySample(
            date: location.timestamp,
            movingState: movingState.movingState,
            recordingState: recordingState,
            location: location
        )
        sample.stepHz = stepHz

        if let wiggles = accelerometerSampler.currentAccelerationData() {
            sample.xyAcceleration = wiggles.xyMean + (wiggles.xySD * 3)
            sample.zAcceleration = wiggles.zMean + (wiggles.zSD * 3)
        }

        return sample
    }

    public func sleepDetectorState() async ->  SleepDetectorState? {
        return await sleepModeDetector.state
    }

    public func movingStateDetails() async -> MovingStateDetails {
        return await stationaryDetector.currentState()
    }

    // MARK: - Private

    private let kalmanFilter = KalmanFilter()
    private let stationaryDetector = StationaryStateDetector()
    private let sleepModeDetector = SleepModeDetector()
    private let accelerometerSampler = AccelerometerSampler()
    private let stepsSampler = StepsMonitor()

    private var backgroundSession: CLBackgroundActivitySession?
    private var fallbackUpdateTimer: Timer?
    private var wakeupTimer: Timer?
    private var standbyTimer: Timer?

    // MARK: -

    private init() {
        _ = locationManager
    }

    // MARK: - State changes

    private func startSleeping() {
        if recordingState != .wakeup {
            DebugLogger.logger.info("LocomotionManager.startSleeping()")
        }

        stopCoreMotion()

        sleepLocationManager.startUpdatingLocation()
        sleepLocationManager.startMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()

        recordingState = .sleeping

        restartTheWakeupTimer()
    }

    private func startWakeup() {
        if recordingState == .wakeup { return }
        if recordingState == .recording { return }

        locationManager.startUpdatingLocation()

        // if in standby, do standby specific checks then exit early
        if recordingState == .standby {
            if let appGroup, appGroup.shouldBeTheRecorder {
                becomeTheActiveRecorder()
            } else {
                startStandby()
            }
            return
        }

        // need to be able to detect nolos
        restartTheFallbackTimer()

        recordingState = .wakeup
    }

    public func becomeTheActiveRecorder() {
        guard let appGroup else { return }
        if appGroup.isAnActiveRecorder { return }
        startRecording()
        DebugLogger.logger.info("tookOverRecording", subsystem: .misc)
        appGroup.becameCurrentRecorder()
    }

    // MARK: -

    private func startCoreMotion() {
        accelerometerSampler.startMonitoring()
        Task { await stepsSampler.startMonitoring() }
    }

    private func stopCoreMotion() {
        accelerometerSampler.stopMonitoring()
        Task { await stepsSampler.stopMonitoring() }
    }

    // MARK: - Incoming locations handling

    internal func add(location: CLLocation) async {
        // only accept locations when recording is supposed to be happening
        guard recordingState == .recording || recordingState == .wakeup else { return }

        await kalmanFilter.add(location: location)
        let kalmanLocation = await kalmanFilter.currentEstimatedLocation()

        await stationaryDetector.add(location: kalmanLocation)
        await sleepModeDetector.add(location: kalmanLocation)

        await updateTheRecordingState()

        await MainActor.run {
            lastFilteredLocation = kalmanLocation
            lastRawLocation = location
            lastUpdated = .now
        }
    }

    private func updateTheRecordingState() async {
        let sleepState = await sleepModeDetector.state

        switch recordingState {
        case .recording:
            if let appGroup, !appGroup.shouldBeTheRecorder {
                startStandby()

            } else if sleepState.shouldBeSleeping {
                startSleeping()

            } else {
                restartTheFallbackTimer()
            }   

        case .wakeup:
            if sleepState.shouldBeSleeping {
                startSleeping()
            } else {
                startRecording()
            }

        case .sleeping, .deepSleeping:
            if let appGroup, appGroup.isAnActiveRecorder, !appGroup.shouldBeTheRecorder {
                startStandby()
            }

        case .standby, .off:
            break
        }
    }

    // MARK: - Timer handling

    private func restartTheFallbackTimer() {
        Task { @MainActor in
            fallbackUpdateTimer?.invalidate()
            fallbackUpdateTimer = Timer.scheduledTimer(withTimeInterval: fallbackUpdateDuration, repeats: false) { [weak self] _ in
                if let self {
                    Task { await self.updateTheRecordingState() }
                }
            }
        }
    }

    private func restartTheWakeupTimer() {
        Task { @MainActor in
            wakeupTimer?.invalidate()
            wakeupTimer = Timer.scheduledTimer(withTimeInterval: sleepCycleDuration, repeats: false) { [weak self] _ in
                self?.startWakeup()
            }
        }
    }

    private func restartTheStandbyTimer() {
        Task { @MainActor in
            standbyTimer?.invalidate()
            standbyTimer = Timer.scheduledTimer(withTimeInterval: standbyCycleDuration, repeats: false) { [weak self] _ in
                self?.startWakeup()
            }
        }
    }

    private func stopTheFallbackTimer() {
        fallbackUpdateTimer?.invalidate()
        fallbackUpdateTimer = nil
    }

    private func stopTheWakeupTimer() {
        wakeupTimer?.invalidate()
        wakeupTimer = nil
    }

    private func stopTheStandbyTimer() {
        standbyTimer?.invalidate()
        standbyTimer = nil
    }

    // MARK: - Location Managers

    @ObservationIgnored
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = 3
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true
        manager.delegate = self.locationDelegate
        return manager
    }()

    @ObservationIgnored
    private lazy var sleepLocationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = kCLLocationAccuracyThreeKilometers
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true
        manager.delegate = self.locationDelegate
        return manager
    }()

    @ObservationIgnored
    private lazy var locationDelegate = {
        return Delegate(parent: self)
    }()

    // MARK: - Debug simulated locations

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

    // MARK: - CLLocationManagerDelegate

    private class Delegate: NSObject, CLLocationManagerDelegate {
        let parent: LocomotionManager

        init(parent: LocomotionManager) {
            self.parent = parent
            super.init()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            Task {
                for location in locations {
                    await parent.add(location: location)
                }
            }
        }

        func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
            DebugLogger.logger.info("locationManagerDidPauseLocationUpdates()")
            parent.startSleeping()
        }

        func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
            DebugLogger.logger.info("locationManagerDidResumeLocationUpdates()")
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            parent.locationAuthorizationStatus = manager.authorizationStatus
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            DebugLogger.logger.error(error, subsystem: .misc)
        }
    }

}
