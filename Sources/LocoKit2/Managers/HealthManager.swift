//
//  HealthManager.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-03-20.
//

import Foundation
import CoreLocation
import HealthKit
import GRDB
import UIKit

@HealthActor
public enum HealthManager {
    
    private static let healthStore = HKHealthStore()

    private static var heartRateSamplesCache: [String: (date: Date, samples: [HKQuantitySample])] = [:]
    private static let cacheDuration: TimeInterval = .hours(1)
    private static let maxCacheSize = 50
    
    private static var lastHealthUpdateTimes: [String: Date] = [:]
    private static let healthUpdateThrottle: TimeInterval = .minutes(15)
    
    private static var healthKitEnabled = false
    
    public static func enableHealthKit() {
        healthKitEnabled = true
    }
    
    public static func disableHealthKit() {
        healthKitEnabled = false
    }
    
    nonisolated
    public static let healthDataTypes: Set<HKQuantityType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate)
    ]
    
    // MARK: - Requesting Access

    public static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)

        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }

    // MARK: - Requested Access States

    public static func haveEverRequestedHealthKitType(_ type: HKQuantityType) -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let status = healthStore.authorizationStatus(for: type)
        return status != .notDetermined
    }

    public static func haveEverRequestedAnyHealthKitType() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        for type in healthDataTypes {
            if healthStore.authorizationStatus(for: type) != .notDetermined {
                return true
            }
        }
        return false
    }
    
    public static func haveRequestedAllHealthKitTypes() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        for type in healthDataTypes {
            if healthStore.authorizationStatus(for: type) == .notDetermined {
                return false
            }
        }
        return true
    }

    // MARK: - Read Access States

    public static func haveAnyReadAccess() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        for type in healthDataTypes {
            if try await checkReadPermission(for: type) {
                return true
            }
        }
        return false
    }
    
    public static func checkReadPermission(for type: HKQuantityType) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let descriptor = HKSourceQueryDescriptor(predicate: .quantitySample(type: type, predicate: nil))
        let sources = try await descriptor.result(for: healthStore)
        return !sources.isEmpty
    }

    // MARK: - Updating TimelineItem Properties

    public static func updateHealthData(for item: TimelineItem, force: Bool = false) async {
        guard healthKitEnabled else { return }
        guard let dateRange = item.dateRange else { return }
        
        if await UIApplication.shared.applicationState == .background { return }

        if !force, let lastUpdate = lastHealthUpdateTimes[item.id], lastUpdate.age < healthUpdateThrottle {
            return
        }
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await updateStepCount(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await updateFlightsClimbed(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await updateActiveEnergy(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await updateHeartRateStats(for: item, from: dateRange.start, to: dateRange.end)
            }

            await group.waitForAll()
        }
        
        lastHealthUpdateTimes[item.id] = .now
    }

    private static func updateStepCount(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        do {
            let stepType = HKQuantityType(.stepCount)
            let sumQuantity = try await fetchSum(for: stepType, from: startDate, to: endDate)

            if let steps = sumQuantity?.doubleValue(for: .count()) {
                do {
                    try await Database.pool.uncancellableWrite { db in
                        var mutableItem = item.base
                        try mutableItem.updateChanges(db) {
                            $0.stepCount = Int(steps)
                        }
                    }

                } catch {
                    logger.error(error, subsystem: .database)
                }
            }

        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }
    
    private static func updateFlightsClimbed(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        do {
            let flightsType = HKQuantityType(.flightsClimbed)
            let sumQuantity = try await fetchSum(for: flightsType, from: startDate, to: endDate)

            if let flights = sumQuantity?.doubleValue(for: .count()) {
                do {
                    try await Database.pool.uncancellableWrite { db in
                        var mutableItem = item.base
                        try mutableItem.updateChanges(db) {
                            $0.floorsAscended = Int(flights)
                        }
                    }
                    
                } catch {
                    logger.error(error, subsystem: .database)
                }
            }
            
        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }
    
    private static func updateActiveEnergy(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        do {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let sumQuantity = try await fetchSum(for: energyType, from: startDate, to: endDate)

            if let energy = sumQuantity?.doubleValue(for: .kilocalorie()) {
                do {
                    try await Database.pool.uncancellableWrite { db in
                        var mutableItem = item.base
                        try mutableItem.updateChanges(db) {
                            $0.activeEnergyBurned = energy
                        }
                    }
                    
                } catch {
                    logger.error(error, subsystem: .database)
                }
            }
            
        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }
    
    private static func updateHeartRateStats(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let heartRateType = HKQuantityType(.heartRate)
        
        do {
            let avgDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: heartRateType, predicate: samplePredicate),
                options: .discreteAverage
            )
            
            let maxDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: heartRateType, predicate: samplePredicate),
                options: .discreteMax
            )
            
            let avgResult = try await avgDescriptor.result(for: healthStore)
            let maxResult = try await maxDescriptor.result(for: healthStore)
            
            let averageQuantity = avgResult?.averageQuantity()
            let maxQuantity = maxResult?.maximumQuantity()
            
            if averageQuantity != nil || maxQuantity != nil {
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let average = averageQuantity?.doubleValue(for: heartRateUnit)
                let max = maxQuantity?.doubleValue(for: heartRateUnit)
                
                try await Database.pool.uncancellableWrite { db in
                    var mutableItem = item.base
                    try mutableItem.updateChanges(db) {
                        if let average { $0.averageHeartRate = average }
                        if let max { $0.maxHeartRate = max }
                    }
                }
            }
            
        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }

    // MARK: - Heart Rate for LocomotionSamples
    
    private static var lastSampleHeartRateUpdateTimes: [String: Date] = [:]
    private static let sampleHeartRateUpdateThrottle: TimeInterval = .minutes(15)
    
    internal static func updateHeartRateForSamples(in item: TimelineItem) async {
        guard healthKitEnabled else { return }
        guard let samples = item.samples, !samples.isEmpty else { return }
        guard let dateRange = item.dateRange else { return }

        // throttle updates to prevent excessive HealthKit queries
        if let lastUpdate = lastSampleHeartRateUpdateTimes[item.id], lastUpdate.age < sampleHeartRateUpdateThrottle {
            return
        }
        
        lastSampleHeartRateUpdateTimes[item.id] = .now

        guard HKHealthStore.isHealthDataAvailable() else { return }
        if await UIApplication.shared.applicationState == .background { return }

        do {
            let heartRateSamples = try await fetchHeartRateSamples(from: dateRange.start, to: dateRange.end)
            if heartRateSamples.isEmpty { return }

            await matchHeartRateToSamples(heartRateSamples: heartRateSamples, locomotionSamples: samples)

        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }

    private static func matchHeartRateToSamples(heartRateSamples: [HKQuantitySample], locomotionSamples: [LocomotionSample]) async {
        guard !heartRateSamples.isEmpty, !locomotionSamples.isEmpty else { return }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        
        let locomotionDict = Dictionary(grouping: locomotionSamples) { sample in
            return Date(timeIntervalSince1970: round(sample.date.timeIntervalSince1970))
        }
        
        // structure to hold sample/heart rate pairs for batch updating
        struct HeartRateUpdate {
            let sample: LocomotionSample
            let heartRate: Double
        }
        
        var updates: [HeartRateUpdate] = []
        
        for hrSample in heartRateSamples {
            let hrValue = hrSample.quantity.doubleValue(for: heartRateUnit)
            let hrDate = hrSample.startDate
            
            // try exact timestamp match first (rounded to nearest second)
            let roundedDate = Date(timeIntervalSince1970: round(hrDate.timeIntervalSince1970))
            if let exactMatches = locomotionDict[roundedDate] {
                for sample in exactMatches {
                    updates.append(HeartRateUpdate(sample: sample, heartRate: hrValue))
                }
                continue
            }
            
            // if no exact match, find nearest sample within threshold
            var closestSample: LocomotionSample?
            var closestTimeDiff = TimeInterval.greatestFiniteMagnitude
            
            for sample in locomotionSamples {
                let timeDiff = abs(sample.date.timeIntervalSince(hrDate))
                if timeDiff < closestTimeDiff {
                    closestTimeDiff = timeDiff
                    closestSample = sample
                }
            }
            
            // only use nearest match if within 15 seconds
            if closestTimeDiff < 15, let sample = closestSample {
                updates.append(HeartRateUpdate(sample: sample, heartRate: hrValue))
            }
        }
        
        if !updates.isEmpty {
            let finalUpdates = updates
            
            do {
                try await Database.pool.uncancellableWrite { db in
                    for update in finalUpdates {
                        var mutableSample = update.sample
                        try mutableSample.updateChanges(db) {
                            $0.heartRate = update.heartRate
                        }
                    }
                }
                
            } catch {
                logger.error(error, subsystem: .database)
            }
        }
    }

    // MARK: - Private Fetching

    private static func fetchSum(for quantityType: HKQuantityType, from startDate: Date, to endDate: Date) async throws -> HKQuantity? {
        let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: samplePredicate),
            options: .cumulativeSum
        )

        return try await descriptor.result(for: healthStore)?.sumQuantity()
    }
    
    private static func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)
        let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: samplePredicate)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: HKObjectQueryNoLimit
        )

        return try await descriptor.result(for: healthStore)
    }

}
