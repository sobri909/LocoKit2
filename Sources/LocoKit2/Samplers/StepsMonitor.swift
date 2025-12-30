//
//  StepsMonitor.swift
//
//
//  Created by Matt Greenfield on 21/3/24.
//

import Foundation
@preconcurrency import CoreMotion
import os

public final class StepsMonitor: Sendable {

    public static let maxDataAge: TimeInterval = 30

    // MARK: - Public

    public func startMonitoring() {
        pedometer.startUpdates(from: .now) { [weak self] pedometerData, error in
            guard let self else { return }

            if let error {
                Log.error(error, subsystem: .locomotion)
            }

            if let pedometerData {
                self.add(pedometerData)
            }
        }
    }

    public func stopMonitoring() {
        pedometer.stopUpdates()
    }

    public func currentStepHz() -> Double? {
        let latestData = lock.withLock { self.latestData }
        guard let latestData else {
            return nil
        }

        guard latestData.endDate.age <= Self.maxDataAge else {
            return nil
        }

        // use the cadence value directly if available
        if let cadence = latestData.currentCadence?.doubleValue {
            return cadence
        }

        // calc from steps count
        let duration = latestData.endDate - latestData.startDate
        let steps = latestData.numberOfSteps.doubleValue
        return steps / duration
    }

    // MARK: - Private

    private let pedometer = CMPedometer()
    
    nonisolated(unsafe)
    private var latestData: CMPedometerData?

    private func add(_ pedometerData: sending CMPedometerData) {
        lock.withLock { [pedometerData] in
            self.latestData = pedometerData
        }
    }

    private let lock = OSAllocatedUnfairLock()

}
