//
//  AccelerometerSampler.swift
//
//
//  Created by Matt Greenfield on 2024-03-22
//

import Foundation
@preconcurrency import CoreMotion
import Synchronization

public final class AccelerometerSampler: Sendable {

    // MARK: - Config

    public static let samplingHz: Double = 4
    public static let maxSampleSize: Int = 30 * 4 // 30 seconds

    // MARK: - Public

    public func startMonitoring() {
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motionData, error in
            guard let self else { return }
            if let error { Log.error(error, subsystem: .locomotion) }
            if let motionData { self.add(motionData) }
        }
    }

    public func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        sample.withLock { $0 = [] }
    }

    public func currentAccelerationData() -> AccelerationData? {
        let sampleCopy = sample.withLock {
            $0 = Array($0.suffix(Self.maxSampleSize))
            return $0
        }

        if sampleCopy.isEmpty { return nil }

        let accelerations = sampleCopy.map { $0.userAccelerationInReferenceFrame }

        let xyValues = accelerations.map { abs($0.x) + abs($0.y) }
        let zValues = accelerations.map { abs($0.z) }

        let xyStats = xyValues.meanAndStandardDeviation()
        let zStats = zValues.meanAndStandardDeviation()

        return AccelerationData(
            xyMean: xyStats.mean,
            zMean: zStats.mean,
            xySD: xyStats.standardDeviation,
            zSD: zStats.standardDeviation
        )
    }

    // MARK: - Private

    private let sample = Mutex<[CMDeviceMotion]>([])

    private func add(_ motionData: CMDeviceMotion) {
        sample.withLock { $0.append(motionData) }
    }

    // MARK: -

    private let motionManager = {
        let manager = CMMotionManager()
        manager.deviceMotionUpdateInterval = 1.0 / AccelerometerSampler.samplingHz
        return manager
    }()

    private let queue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

}

public struct AccelerationData {
    let xyMean: Double
    let zMean: Double
    let xySD: Double
    let zSD: Double
}
