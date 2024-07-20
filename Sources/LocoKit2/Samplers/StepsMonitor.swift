//
//  StepsMonitor.swift
//
//
//  Created by Matt Greenfield on 21/3/24.
//

import Foundation
@preconcurrency import CoreMotion

public actor StepsMonitor {

    // MARK: - Config

    public static let maxDataAge: TimeInterval = 30

    // MARK: - Public

    public func startMonitoring() {
        pedometer.startUpdates(from: .now) { [weak self] pedometerData, error in
            guard let self else { return }

            if let error {
                logger.error(error, subsystem: .misc)
            }

            if let pedometerData {
                Task { await self.add(pedometerData) }
            }
        }
    }

    public func stopMonitoring() {
        pedometer.stopUpdates()
    }

    public func currentStepHz() -> Double? {
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
    private var latestData: CMPedometerData?

    private func add(_ pedometerData: CMPedometerData) {
        self.latestData = pedometerData
    }

}
