//
//  AccelerometerSampler.swift
//
//
//  Created by Matt Greenfield on 22/3/24.
//

import Foundation
@preconcurrency import CoreMotion
import os

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
        lock.withLock {
            sample = []
        }
    }

    public func currentAccelerationData() -> AccelerationData? {
        let sampleCopy = lock.withLock {
            sample = sample.suffix(Self.maxSampleSize)
            return sample
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

    nonisolated(unsafe)
    private var sample: [CMDeviceMotion] = []

    private func add(_ motionData: CMDeviceMotion) {
        lock.withLock {
            sample.append(motionData)
        }
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

    private let lock = OSAllocatedUnfairLock()

}

public struct AccelerationData {
    let xyMean: Double
    let zMean: Double
    let xySD: Double
    let zSD: Double
}
