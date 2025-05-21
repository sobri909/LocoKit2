//
//  LocomotionManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import Observation
import CoreLocation
import CoreMotion

@Observable
public final class LocomotionManager: @unchecked Sendable {

    public static let highlander = LocomotionManager()

    // this is a dumb place to put this
    public static let locoKitVersion = "9.0.0"

    // MARK: - Public

    @MainActor
    public private(set) var sleepCycleDuration: TimeInterval = 30

    @MainActor
    public func setSleepCycleDuration(_ duration: TimeInterval) {
        sleepCycleDuration = duration
    }

    public var standbyCycleDuration: TimeInterval = 60 * 2
    public var fallbackUpdateDuration: TimeInterval = 6

    @ObservationIgnored
    public var appGroup: AppGroup?

    @MainActor
    public private(set) var recordingState: RecordingState = .off {
        didSet {
            Task { await appGroup?.save() }
            for continuation in stateContinuations.values {
                continuation.yield(recordingState)
            }
        }
    }

    public internal(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    public internal(set) var motionAuthorizationStatus: CMAuthorizationStatus = {
        CMMotionActivityManager.authorizationStatus()
    }()
    
    public var hasNecessaryPermissions: Bool {
        if locationAuthorizationStatus != .authorizedAlways && locationAuthorizationStatus != .authorizedWhenInUse {
            return false
        }
        
        if motionAuthorizationStatus != .authorized {
            return false
        }
        
        return true
    }

    public private(set) var lastUpdated: Date?
    public private(set) var lastRawLocation: CLLocation?
    public private(set) var lastFilteredLocation: CLLocation? {
        didSet {
            if let location = lastFilteredLocation {
                locationContinuation?.yield(location)
            }
        }
    }

    // MARK: -

    public func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.locationContinuation = continuation
        }
    }

    private var locationContinuation: AsyncStream<CLLocation>.Continuation?

    public func stateUpdates() -> AsyncStream<RecordingState> {
        AsyncStream { continuation in
            let id = UUID()
            stateContinuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                self.stateContinuations.removeValue(forKey: id)
            }
        }
    }

    private var stateContinuations: [UUID: AsyncStream<RecordingState>.Continuation] = [:]

    // MARK: - Recording states

    @MainActor
    public func startRecording() {
        if recordingState == .recording { return }

        print("LocomotionManager.startRecording()")

        recordingState = .recording

        if backgroundSession == nil {
            backgroundSession = CLBackgroundActivitySession()
        }

        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        sleepLocationManager.stopUpdatingLocation()

        startCoreMotion()

        restartTheFallbackTimer()
    }

    @MainActor
    public func stopRecording() {
        print("LocomotionManager.stopRecording()")

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

    @MainActor
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
        locationManager.requestAlwaysAuthorization()
    }

    public func requestMotionAuthorization() async {
        await withCheckedContinuation { continuation in
            motionAuthPedometer.queryPedometerData(from: .now - .hours(1), to: .now) { data, error in
                if let error { logger.error(error, subsystem: .locomotion) }
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
        let stepHz = stepsSampler.currentStepHz()

        var sample = LocomotionSample(
            date: .now,
            movingState: movingState.movingState,
            recordingState: await recordingState,
            location: location
        )

        // store nil as zero, because CMPedometer returns nil while stationary
        sample.stepHz = stepHz ?? 0

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

    @ObservationIgnored
    private var backgroundSession: CLBackgroundActivitySession?

    // MARK: -

    private init() {
        locationDelegate = Delegate(parent: self)
        locationManager.delegate = locationDelegate
        sleepLocationManager.delegate = locationDelegate
    }

    // MARK: - State changes
    @MainActor
    private func startSleeping() {
        if recordingState != .wakeup {
            print("LocomotionManager.startSleeping()")
        }

        stopCoreMotion()

        sleepLocationManager.startUpdatingLocation()
        sleepLocationManager.startMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()

        recordingState = .sleeping

        restartTheWakeupTimer()
    }

    @MainActor
    private func startWakeup() async {
        if recordingState == .wakeup { return }
        if recordingState == .recording { return }

        locationManager.startUpdatingLocation()

        // if in standby, do standby specific checks then exit early
        if recordingState == .standby {
            if let appGroup, appGroup.shouldBeTheRecorder {
                await becomeTheActiveRecorder()
            } else {
                startStandby()
            }
            return
        }

        // need to be able to detect nolos
        restartTheFallbackTimer()

        recordingState = .wakeup
    }

    public func becomeTheActiveRecorder() async {
        guard let appGroup else { return }
        if await appGroup.isAnActiveRecorder { return }
        await startRecording()
        logger.info("tookOverRecording", subsystem: .timeline)
        await appGroup.becameCurrentRecorder()
    }

    // MARK: -

    private func startCoreMotion() {
        accelerometerSampler.startMonitoring()
        stepsSampler.startMonitoring()
    }

    private func stopCoreMotion() {
        accelerometerSampler.stopMonitoring()
        stepsSampler.stopMonitoring()
    }

    // MARK: - Incoming locations handling
    
    @MainActor
    internal func add(location: CLLocation) async {
        // only accept locations when recording is supposed to be happening
        guard recordingState == .recording || recordingState == .wakeup else { return }

        await kalmanFilter.add(location: location)
        let kalmanLocation = await kalmanFilter.currentEstimatedLocation()

        await stationaryDetector.add(location: kalmanLocation)
        await sleepModeDetector.add(location: kalmanLocation)

        await updateTheRecordingState()

        lastFilteredLocation = kalmanLocation
        lastRawLocation = location
        lastUpdated = .now
    }

    @MainActor
    private func updateTheRecordingState() async {
        let sleepState = await sleepModeDetector.state

        switch recordingState {
        case .recording:
            if let appGroup, !appGroup.shouldBeTheRecorder {
                startStandby()

            } else if sleepState.shouldBeSleeping {
                if await TimelineRecorder.canStartSleeping {
                    startSleeping()
                } else {
                    restartTheFallbackTimer()
                }
                
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
            if let appGroup, await appGroup.isAnActiveRecorder, !appGroup.shouldBeTheRecorder {
                startStandby()
            } else if !(await TimelineRecorder.canStartSleeping) {
                startRecording()
            }

        case .standby, .off:
            break
        }
    }

    // MARK: - Timer handling

    private var wakeupTimer: Timer?
    private var standbyTimer: Timer?
    private var fallbackUpdateTimer: Timer?

    private func restartTheFallbackTimer() {
        let duration = fallbackUpdateDuration
        Task { @MainActor in
            fallbackUpdateTimer?.invalidate()
            fallbackUpdateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                if let self {
                    Task { await self.updateTheRecordingState() }
                }
            }
        }
    }

    @MainActor
    private func restartTheWakeupTimer() {
        let duration = sleepCycleDuration
        Task { @MainActor in
            wakeupTimer?.invalidate()
            wakeupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                if let self {
                    Task { await self.startWakeup() }
                }
            }
        }
    }

    private func restartTheStandbyTimer() {
        let duration = standbyCycleDuration
        Task { @MainActor in
            standbyTimer?.invalidate()
            standbyTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                if let self {
                    Task { await self.startWakeup() }
                }
            }
        }
    }

    private func stopTheFallbackTimer() {
        Task { @MainActor in
            fallbackUpdateTimer?.invalidate()
            fallbackUpdateTimer = nil
        }
    }

    private func stopTheWakeupTimer() {
        Task { @MainActor in
            wakeupTimer?.invalidate()
            wakeupTimer = nil
        }
    }

    private func stopTheStandbyTimer() {
        Task { @MainActor in
            standbyTimer?.invalidate()
            standbyTimer = nil
        }
    }

    // MARK: - Location Managers

    @ObservationIgnored
    private let locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = 3
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true
        return manager
    }()

    @ObservationIgnored
    private let sleepLocationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = kCLLocationAccuracyThreeKilometers
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.allowsBackgroundLocationUpdates = true
        return manager
    }()

    @ObservationIgnored
    private var locationDelegate: Delegate?

    // MARK: - CLLocationManagerDelegate

    private final class Delegate: NSObject, CLLocationManagerDelegate, Sendable {
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
            print("locationManagerDidPauseLocationUpdates()")

            Task { @MainActor in
                self.parent.startSleeping()
            }
        }

        func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
            print("locationManagerDidResumeLocationUpdates()")
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            parent.locationAuthorizationStatus = manager.authorizationStatus
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            if let clError = error as? CLError, clError.code == .locationUnknown {
                return
            }
            logger.error(error, subsystem: .locomotion)
        }
    }

}
