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
    
    nonisolated
    private static let healthDataTypes: Set<HKQuantityType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate)
    ]
    
    // MARK: - Auth

    public static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)

        } catch {
            logger.error(error, subsystem: .healthkit)
        }
    }
    
    public static func haveAnyReadAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        for type in healthDataTypes {
            if await checkReadPermission(for: type) {
                return true
            }
        }
        return false
    }
    
    public static func checkReadPermission(for type: HKQuantityType) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        do {
            let descriptor = HKSourceQueryDescriptor(predicate: .quantitySample(type: type, predicate: nil))
            let sources = try await descriptor.result(for: healthStore)
            return !sources.isEmpty

        } catch {
            logger.error(error, subsystem: .healthkit)
            return false
        }
    }
    
    // MARK: - TimelineItem Health Data
    
    public static func heartRateSamples(for item: TimelineItem) async -> [HKQuantitySample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        guard let dateRange = item.dateRange else { return [] }
        
        if let cached = heartRateSamplesCache[item.id], cached.date.age < cacheDuration {
            return cached.samples
        }
        
        let samples = await fetchHeartRateSamples(from: dateRange.start, to: dateRange.end)
        
        if heartRateSamplesCache.count >= maxCacheSize {
            let oldestKey = heartRateSamplesCache.min(by: { $0.value.date < $1.value.date })?.key
            if let oldestKey {
                heartRateSamplesCache.removeValue(forKey: oldestKey)
            }
        }
        
        heartRateSamplesCache[item.id] = (date: .now, samples: samples)
        
        return samples
    }
    
    public static func clearCache(for itemId: String) {
        heartRateSamplesCache.removeValue(forKey: itemId)
    }
    
    public static func clearAllCaches() {
        heartRateSamplesCache.removeAll()
    }
    
    public static func updateHealthData(for item: TimelineItem, force: Bool = false) async {
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
    
    // MARK: - Private Helpers

    private static func updateStepCount(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        let stepType = HKQuantityType(.stepCount)
        let sumQuantity = await fetchSum(for: stepType, from: startDate, to: endDate)
        
        if let steps = sumQuantity?.doubleValue(for: .count()) {
            do {
                try await Database.pool.write { db in
                    var mutableItem = item.base
                    try mutableItem.updateChanges(db) {
                        $0.stepCount = Int(steps)
                    }
                }
                
            } catch {
                logger.error(error, subsystem: .healthkit)
            }
        }
    }
    
    private static func updateFlightsClimbed(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        let flightsType = HKQuantityType(.flightsClimbed)
        let sumQuantity = await fetchSum(for: flightsType, from: startDate, to: endDate)
        
        if let flights = sumQuantity?.doubleValue(for: .count()) {
            do {
                try await Database.pool.write { db in
                    var mutableItem = item.base
                    try mutableItem.updateChanges(db) {
                        $0.floorsAscended = Int(flights)
                    }
                }
                
            } catch {
                logger.error(error, subsystem: .healthkit)
            }
        }
    }
    
    private static func updateActiveEnergy(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let sumQuantity = await fetchSum(for: energyType, from: startDate, to: endDate)
        
        if let energy = sumQuantity?.doubleValue(for: .kilocalorie()) {
            do {
                try await Database.pool.write { db in
                    var mutableItem = item.base
                    try mutableItem.updateChanges(db) {
                        $0.activeEnergyBurned = energy
                    }
                }
                
            } catch {
                logger.error(error, subsystem: .healthkit)
            }
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
                
                try await Database.pool.write { db in
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
    
    private static func fetchSum(for quantityType: HKQuantityType, from startDate: Date, to endDate: Date) async -> HKQuantity? {
        let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: quantityType, predicate: samplePredicate),
                options: .cumulativeSum
            )
            
            let statistics = try await descriptor.result(for: healthStore)
            return statistics?.sumQuantity()
            
        } catch {
            logger.error(error, subsystem: .healthkit)
            return nil
        }
    }
    
    private static func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)
        let samplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: heartRateType, predicate: samplePredicate)],
                sortDescriptors: [SortDescriptor(\.startDate)],
                limit: HKObjectQueryNoLimit
            )
            
            let samples = try await descriptor.result(for: healthStore)
            return samples
            
        } catch {
            logger.error(error, subsystem: .healthkit)
            return []
        }
    }
}
