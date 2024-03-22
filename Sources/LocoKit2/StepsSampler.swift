//
//  StepsSampler.swift
//
//
//  Created by Matt Greenfield on 21/3/24.
//

import Foundation
import CoreMotion

actor StepsSampler {

    // MARK: - Config

    private let sampleDuration: TimeInterval = 6.0 

    // MARK: - Public

    func startSampling() {
        pedometer.startUpdates(from: .now) { [weak self] pedometerData, error in
            guard let self else { return }

            if let error {
                DebugLogger.logger.error(error, subsystem: .misc)
                return
            }

            if let pedometerData {
                Task { await self.add(pedometerData) }
            }
        }
    }

    func stopSampling() {
        pedometer.stopUpdates()
    }

    func currentState() -> StepsSampleState? {
        guard let lastSample = samples.last else {
            return nil
        }

        // use the cadence value directly if available
        if let cadence = lastSample.currentCadence?.doubleValue, cadence >= 0 {
            let duration = lastSample.endDate.timeIntervalSince(lastSample.startDate)
            return StepsSampleState(stepHz: cadence, sampleCount: samples.count, duration: duration)

        } else { // calculate stepHz from step counts
            let stepCounts = samples.compactMap { $0.numberOfSteps.doubleValue }
            let totalSteps = stepCounts.reduce(0, +)

            if let firstSample = samples.first {
                let duration = lastSample.endDate.timeIntervalSince(firstSample.startDate)
                let stepHz = duration > 0 ? Double(totalSteps) / duration : 0
                return StepsSampleState(stepHz: stepHz, sampleCount: samples.count, duration: duration)

            } else {
                return nil
            }
        }
    }

    // MARK: - Private

    private let pedometer = CMPedometer()
    private var samples: [CMPedometerData] = []

    private func add(_ pedometerData: CMPedometerData) {
        samples.append(pedometerData)

        // Remove samples older than the desired duration
        while let oldest = samples.first, oldest.startDate.age > sampleDuration {
            samples.removeFirst()
        }
    }

}

public struct StepsSampleState {
    public let stepHz: Double
    public let sampleCount: Int
    public let duration: TimeInterval
}
