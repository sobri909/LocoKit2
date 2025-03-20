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

@HealthActor
public enum HealthManager {
    
    // MARK: - Properties
    
    private static let healthStore = HKHealthStore()
    private static var isAuthorized = false
    
    private static var heartRateSamplesCache: [String: (date: Date, samples: [HKQuantitySample])] = [:]
    private static let cacheDuration: TimeInterval = .hours(1)
    private static let maxCacheSize = 50
    
    // MARK: - Authorization
    
    public static func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            return true
            
        } catch {
            logger.error(error, subsystem: .misc)
            return false
        }
    }
    
    public static func checkAuthorization() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let stepCountType = HKQuantityType(.stepCount)
        let authStatus = healthStore.authorizationStatus(for: stepCountType)
        return authStatus == .sharingAuthorized
    }
    
    // MARK: - TimelineItem Health Data
    
    public static func fetchHealthData(for item: TimelineItem) async {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized || checkAuthorization() else { return }
        guard let dateRange = item.dateRange else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await fetchAndUpdateStepCount(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await fetchAndUpdateFlightsClimbed(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await fetchAndUpdateActiveEnergy(for: item, from: dateRange.start, to: dateRange.end)
            }
            
            group.addTask {
                await fetchAndUpdateHeartRateStats(for: item, from: dateRange.start, to: dateRange.end)
            }

            await group.waitForAll()
        }
    }
    
    // MARK: - Heart Rate Samples (in-memory cache)
    
    public static func heartRateSamples(for item: TimelineItem) async -> [HKQuantitySample] {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized || checkAuthorization() else { return [] }
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
    
    // MARK: - Private Helpers
    
    private static func fetchAndUpdateStepCount(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
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
                logger.error(error, subsystem: .misc)
            }
        }
    }
    
    private static func fetchAndUpdateFlightsClimbed(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
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
                logger.error(error, subsystem: .misc)
            }
        }
    }
    
    private static func fetchAndUpdateActiveEnergy(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
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
                logger.error(error, subsystem: .misc)
            }
        }
    }
    
    private static func fetchAndUpdateHeartRateStats(for item: TimelineItem, from startDate: Date, to endDate: Date) async {
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
            
            // Execute queries sequentially to avoid data races
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
            logger.error(error, subsystem: .misc)
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
            logger.error(error, subsystem: .misc)
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
            logger.error(error, subsystem: .misc)
            return []
        }
    }
}
