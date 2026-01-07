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
    
    public static let healthStore = HKHealthStore()

    private static var lastHealthUpdateTimes: [String: Date] = [:]
    private static let healthUpdateThrottle: TimeInterval = .minutes(15)
    
    // MARK: - Health Data Types

    /// types used for activity classification (strongly recommended)
    nonisolated
    public static let classificationTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate)
    ]

    /// types used for timeline stats display (optional)
    nonisolated
    public static let statsTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned)
    ]

    /// all LocoKit2 health data types
    nonisolated
    public static let healthDataTypes: Set<HKObjectType> = classificationTypes.union(statsTypes)

    // MARK: - Enable / Disable

    public private(set) static var healthKitEnabled = false

    public static func enableHealthKit() {
        healthKitEnabled = true
    }

    public static func disableHealthKit() {
        healthKitEnabled = false
    }

    // MARK: - Requesting Access

    public static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)

        } catch {
            Log.error(error, subsystem: .healthkit)
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
    
    public static func checkReadPermission(for type: HKObjectType) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        if let quantityType = type as? HKQuantityType {
            let descriptor = HKSourceQueryDescriptor(predicate: .quantitySample(type: quantityType, predicate: nil))
            let sources = try await descriptor.result(for: healthStore)
            return !sources.isEmpty

        } else if let categoryType = type as? HKCategoryType {
            let descriptor = HKSourceQueryDescriptor(predicate: .categorySample(type: categoryType, predicate: nil))
            let sources = try await descriptor.result(for: healthStore)
            return !sources.isEmpty
        }
        
        return false
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
        
        // fetch all health data concurrently
        async let steps = fetchStepCount(from: dateRange.start, to: dateRange.end)
        async let flights = fetchFlightsClimbed(from: dateRange.start, to: dateRange.end)
        async let energy = fetchActiveEnergy(from: dateRange.start, to: dateRange.end)
        async let heartRateStats = fetchHeartRateStats(from: dateRange.start, to: dateRange.end)
        
        // wait for all results
        let stepCount = await steps
        let floorsAscended = await flights
        let activeEnergyBurned = await energy
        let (averageHeartRate, maxHeartRate) = await heartRateStats
        
        // check if we have any data to update
        guard stepCount != nil || floorsAscended != nil || activeEnergyBurned != nil || 
              averageHeartRate != nil || maxHeartRate != nil else {
            return
        }
        
        // single consolidated database write
        do {
            try await Database.pool.uncancellableWrite { db in
                var mutableItem = item.base
                try mutableItem.updateChanges(db) { item in
                    if let stepCount { item.stepCount = stepCount }
                    if let floorsAscended { item.floorsAscended = floorsAscended }
                    if let activeEnergyBurned { item.activeEnergyBurned = activeEnergyBurned }
                    if let averageHeartRate { item.averageHeartRate = averageHeartRate }
                    if let maxHeartRate { item.maxHeartRate = maxHeartRate }
                }
            }
        } catch {
            Log.error(error, subsystem: .database)
        }
        
        lastHealthUpdateTimes[item.id] = .now
    }

    private static func fetchStepCount(from startDate: Date, to endDate: Date) async -> Int? {
        do {
            let stepType = HKQuantityType(.stepCount)
            let sumQuantity = try await fetchSum(for: stepType, from: startDate, to: endDate)
            
            if let steps = sumQuantity?.doubleValue(for: .count()) {
                return Int(steps)
            }
            return nil
            
        } catch {
            Log.error(error, subsystem: .healthkit)
            return nil
        }
    }
    
    private static func fetchFlightsClimbed(from startDate: Date, to endDate: Date) async -> Int? {
        do {
            let flightsType = HKQuantityType(.flightsClimbed)
            let sumQuantity = try await fetchSum(for: flightsType, from: startDate, to: endDate)
            
            if let flights = sumQuantity?.doubleValue(for: .count()) {
                return Int(flights)
            }
            return nil
            
        } catch {
            Log.error(error, subsystem: .healthkit)
            return nil
        }
    }
    
    private static func fetchActiveEnergy(from startDate: Date, to endDate: Date) async -> Double? {
        do {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let sumQuantity = try await fetchSum(for: energyType, from: startDate, to: endDate)
            
            if let energy = sumQuantity?.doubleValue(for: .kilocalorie()) {
                return energy
            }
            return nil
            
        } catch {
            Log.error(error, subsystem: .healthkit)
            return nil
        }
    }
    
    private static func fetchHeartRateStats(from startDate: Date, to endDate: Date) async -> (average: Double?, max: Double?) {
        do {
            let avgResult = try await TaskTimeout.withTimeout(seconds: 10) {
                let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                let heartRateType = HKQuantityType(.heartRate)
                let avgDescriptor = HKStatisticsQueryDescriptor(
                    predicate: .quantitySample(type: heartRateType, predicate: samplePredicate),
                    options: .discreteAverage
                )
                return try await avgDescriptor.result(for: healthStore)
            }
            
            let maxResult = try await TaskTimeout.withTimeout(seconds: 10) {
                let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                let heartRateType = HKQuantityType(.heartRate)
                let maxDescriptor = HKStatisticsQueryDescriptor(
                    predicate: .quantitySample(type: heartRateType, predicate: samplePredicate),
                    options: .discreteMax
                )
                return try await maxDescriptor.result(for: healthStore)
            }
            
            if avgResult == nil {
                print("HealthKit average heart rate query timed out")
            }
            if maxResult == nil {
                print("HealthKit max heart rate query timed out")
            }
            
            let averageQuantity = avgResult??.averageQuantity()
            let maxQuantity = maxResult??.maximumQuantity()
            
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let average = averageQuantity?.doubleValue(for: heartRateUnit)
            let max = maxQuantity?.doubleValue(for: heartRateUnit)
            
            return (average: average, max: max)
            
        } catch {
            Log.error(error, subsystem: .healthkit)
            return (average: nil, max: nil)
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
            Log.error(error, subsystem: .healthkit)
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
                Log.error(error, subsystem: .database)
            }
        }
    }

    // MARK: - Public Fetching

    public static func heartRateSamples(for item: TimelineItem) async throws -> [HKQuantitySample] {
        guard healthKitEnabled else { return [] }
        guard let dateRange = item.dateRange else { return [] }
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        guard await UIApplication.shared.applicationState != .background else {
            throw TimelineError.backgroundRestriction
        }

        return try await fetchHeartRateSamples(from: dateRange.start, to: dateRange.end)
    }

    // MARK: - Private Fetching

    private static func fetchSum(for quantityType: HKQuantityType, from startDate: Date, to endDate: Date) async throws -> HKQuantity? {
        let result = try await TaskTimeout.withTimeout(seconds: 10) {
            let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: quantityType, predicate: samplePredicate),
                options: .cumulativeSum
            )
            return try await descriptor.result(for: healthStore)
        }
        
        guard let statistics = result else {
            print("HealthKit query timed out for \(quantityType)")
            return nil
        }
        
        return statistics?.sumQuantity()
    }
    
    private static func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let result = try await TaskTimeout.withTimeout(seconds: 10) {
            let heartRateType = HKQuantityType(.heartRate)
            let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: heartRateType, predicate: samplePredicate)],
                sortDescriptors: [SortDescriptor(\.startDate)],
                limit: HKObjectQueryNoLimit
            )
            return try await descriptor.result(for: healthStore)
        }
        
        guard let samples = result else {
            print("HealthKit heart rate query timed out")
            return []
        }
        
        return samples
    }

}
