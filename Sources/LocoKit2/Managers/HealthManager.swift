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

    // MARK: - Logging (BIG-980)

    /// HealthKit's `errorDatabaseInaccessible` (code 6, "Protected health data is inaccessible"): protected
    /// health data was unavailable when HealthKit answered, which is the device being locked. Matches the
    /// bridged `NSError` and the native `HKError` alike.
    nonisolated
    public static func isDataInaccessible(_ error: Error) -> Bool {
        (error as? HKError)?.code == .errorDatabaseInaccessible
    }

    /// Logs a caught HealthKit failure, except the one that says nothing about the query or the data: code 6
    /// (the device was locked) goes to debug, console only, never the file log. Every other error keeps its
    /// ERROR line, with the caller's file and function as `Log.error` writes them (BIG-745). Use it where a
    /// locked-out query is simply retried the next time its surface is shown; a site where code 6 has a
    /// consequence of its own (`Session.updateHealthKitState` disables HealthKit on it) logs that itself.
    nonisolated
    public static func logError(_ error: Error, function: String = #function, fileID: String = #fileID) {
        if isDataInaccessible(error) {
            Log.debug("\(error) — in \(fileID) \(function)", subsystem: .healthkit)
        } else {
            Log.error(error, subsystem: .healthkit, function: function, fileID: fileID)
        }
    }

    // MARK: - Requesting Access

    public static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)

        } catch {
            logError(error)
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

    // MARK: - Updating TimelineItem health stats (BIG-963)

    /// The item-level sums and heart rate figures for one date range.
    struct HealthStats: Sendable {
        let stepCount: Int?
        let floorsAscended: Int?
        let activeEnergyBurned: Double?
        let averageHeartRate: Double?
        let maxHeartRate: Double?
    }

    /// One item's fetched health data, for `writeHealthResults`.
    struct ItemHealthResult: Sendable {
        let itemId: String
        /// The range the stats were fetched for. The checked date is stamped only while the row still has it.
        let startDate: Date
        let endDate: Date
        /// What came back; a query that failed leaves its figure nil here.
        let stats: HealthStats
        /// Sample id → matched heart rate.
        let sampleHeartRates: [String: Double]
        /// Every query succeeded. Only then is the item stamped checked; otherwise what did come back is
        /// written, and the item is tried again once the throttle allows.
        let complete: Bool
    }

    /// A HealthKit query that ran out of time. Counted as a failure, not as "no data", so the item
    /// stays unchecked and is tried again.
    struct HealthQueryTimeout: Error {}

    /// Fills HealthKit data (the item's sums, and heart rates on its samples) for the items that need
    /// it: those whose `healthUpdated` is nil, because they were never checked or their date range has
    /// moved since. Foreground only: HealthKit can't be read while the phone is locked, and a background
    /// app can't tell locked from merely backgrounded. So this is called from the visible day's segment,
    /// not from `updateFrom`, which runs in the background too (BIG-963).
    ///
    /// An item is stamped checked even when HealthKit has nothing for it, so an empty item isn't queried
    /// again at every launch. One with a query that failed or timed out gets what did come back, and stays
    /// unchecked. Each item is queried at most once per `healthUpdateThrottle`, which is what paces a
    /// recording item: its end moves with every sample, so its date never stays set for long.
    public static func updateHealthIfNeeded(for items: [TimelineItem]) async {
        guard healthKitEnabled else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var results: [ItemHealthResult] = []
        var incomplete = 0
        var firstFailure: String?
        var lockedOut = 0

        for item in items {
            if Task.isCancelled { break }
            // per item, not once per pass: a phone locked mid-pass fails every query after it (HealthKit
            // error 6), and each failed item would then sit out the throttle for nothing
            if await UIApplication.shared.applicationState == .background { break }
            guard !item.deleted, item.base.healthUpdated == nil,
                  let startDate = item.base.startDate, let endDate = item.base.endDate else { continue }
            if let lastUpdate = lastHealthUpdateTimes[item.id], lastUpdate.age < healthUpdateThrottle { continue }
            lastHealthUpdateTimes[item.id] = .now

            let fetched = await fetchHealth(from: startDate, to: endDate, samples: item.samples ?? [])
            // a segment torn down mid-fetch cancels its queries, which then read as failures; drop the item
            // rather than log a failure that wasn't one (the throttle lapses and it's tried again)
            if Task.isCancelled { break }
            if !fetched.complete {
                // an item whose every failure is "the device was locked" (HealthKit code 6) is counted apart:
                // it stays unchecked like any other, but the line for it isn't an error (BIG-980). The ERROR
                // line's example is the first failure that is NOT code 6, so a mixed item never prints one.
                if fetched.failures.allSatisfy(isDataInaccessible) {
                    lockedOut += 1
                } else {
                    incomplete += 1
                    if firstFailure == nil {
                        firstFailure = fetched.failures.first(where: { !isDataInaccessible($0) }).map { "\($0)" }
                    }
                }
            }
            results.append(ItemHealthResult(
                itemId: item.id,
                startDate: startDate,
                endDate: endDate,
                stats: fetched.stats,
                sampleHeartRates: fetched.sampleHeartRates,
                complete: fetched.complete
            ))
        }

        if incomplete > 0 {
            Log.error("HealthManager: \(incomplete) of \(results.count) items had a health query fail, left unchecked; first: \(firstFailure ?? "?")", subsystem: .healthkit)
        }
        if lockedOut > 0 {
            Log.info("HealthManager: \(lockedOut) of \(results.count) items had protected health data unavailable (device locked, HealthKit code 6), left unchecked (BIG-980)", subsystem: .healthkit)
        }

        guard !results.isEmpty else { return }

        do {
            let stamped = try await writeHealthResults(results, checkedAt: .now)
            Log.info("HealthManager: health fetched for \(results.count) items, \(stamped) stamped checked (BIG-963)", subsystem: .healthkit)
        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    /// The write half of `updateHealthIfNeeded`, separate so the stamp's condition can be tested without
    /// HealthKit. The stats and heart rates are written for the range that was fetched, which is fresher
    /// than what's stored. The checked date is stamped only for a complete fetch, and only if the row's
    /// dates still equal that range: otherwise the range moved while HealthKit was answering, the dates
    /// trigger had nothing to clear (the date was already nil), and a stamp would claim a range nobody
    /// fetched. The item then stays unchecked and the next pass fetches its new range.
    /// Returns how many items were stamped.
    @discardableResult
    static func writeHealthResults(_ results: [ItemHealthResult], checkedAt: Date) async throws -> Int {
        try await Database.pool.uncancellableWrite { db in
            var stamped = 0
            for result in results {
                // Only figures that came back are written; a nil never overwrites a stored figure.
                // HealthKit answers nil both for "nothing in this range" and for history it doesn't hold
                // (an imported item's stats can predate this phone's HealthKit), and wiping the second is
                // worse than a shrunk range keeping a figure it no longer earns.
                // Only figures that differ, too: an unchanged write still bumps lastSaved (a backup bucket
                // rewritten, a segment refetch), and an item whose one failing query keeps it unstamped
                // would otherwise be rewritten every throttle period while its day is open.
                guard let stored = try TimelineItemBase.fetchOne(db, key: result.itemId) else { continue }
                var stats: [ColumnAssignment] = []
                if let value = result.stats.stepCount, value != stored.stepCount {
                    stats.append(TimelineItemBase.Columns.stepCount.set(to: value))
                }
                if let value = result.stats.floorsAscended, value != stored.floorsAscended {
                    stats.append(TimelineItemBase.Columns.floorsAscended.set(to: value))
                }
                if let value = result.stats.activeEnergyBurned, value != stored.activeEnergyBurned {
                    stats.append(TimelineItemBase.Columns.activeEnergyBurned.set(to: value))
                }
                if let value = result.stats.averageHeartRate, value != stored.averageHeartRate {
                    stats.append(TimelineItemBase.Columns.averageHeartRate.set(to: value))
                }
                if let value = result.stats.maxHeartRate, value != stored.maxHeartRate {
                    stats.append(TimelineItemBase.Columns.maxHeartRate.set(to: value))
                }
                if !stats.isEmpty {
                    try TimelineItemBase.filter(key: result.itemId).updateAll(db, stats)
                }

                // only rates that differ: an unchanged write still fires the sample's lastSaved trigger,
                // which would send its week back through the next incremental backup
                for (sampleId, heartRate) in result.sampleHeartRates {
                    try LocomotionSample
                        .filter(key: sampleId)
                        .filter(LocomotionSample.Columns.heartRate == nil || LocomotionSample.Columns.heartRate != heartRate)
                        .updateAll(db, LocomotionSample.Columns.heartRate.set(to: heartRate))
                }

                guard result.complete else { continue }
                stamped += try TimelineItemBase
                    .filter(key: result.itemId)
                    .filter(TimelineItemBase.Columns.startDate == result.startDate)
                    .filter(TimelineItemBase.Columns.endDate == result.endDate)
                    .updateAll(db, TimelineItemBase.Columns.healthUpdated.set(to: checkedAt))
            }
            return stamped
        }
    }

    private struct FetchedHealth: Sendable {
        let stats: HealthStats
        let sampleHeartRates: [String: Double]
        let complete: Bool
        /// Every query that failed, in query order; empty when `complete`.
        let failures: [Error]
    }

    /// The five queries for one range, each kept on its own, so one that fails or times out costs only its
    /// own figure (as each stat did before BIG-963) and marks the fetch incomplete.
    private static func fetchHealth(from startDate: Date, to endDate: Date, samples: [LocomotionSample]) async -> FetchedHealth {
        async let steps = attempt { try await fetchStepCount(from: startDate, to: endDate) }
        async let flights = attempt { try await fetchFlightsClimbed(from: startDate, to: endDate) }
        async let energy = attempt { try await fetchActiveEnergy(from: startDate, to: endDate) }
        async let heartRateStats = attempt { try await fetchHeartRateStats(from: startDate, to: endDate) }
        async let sampleRates = attempt { () async throws -> [String: Double] in
            let readings = try await fetchHeartRateSamples(from: startDate, to: endDate)
            return heartRates(from: readings, for: samples)
        }
        let (stepsResult, flightsResult, energyResult, heartRateStatsResult, sampleRatesResult) =
            await (steps, flights, energy, heartRateStats, sampleRates)

        let failures: [Error] = [
            stepsResult.failureValue, flightsResult.failureValue, energyResult.failureValue,
            heartRateStatsResult.failureValue, sampleRatesResult.failureValue
        ].compactMap { $0 }

        let heartRateFigures = try? heartRateStatsResult.get()
        return FetchedHealth(
            stats: HealthStats(
                stepCount: try? stepsResult.get(),
                floorsAscended: try? flightsResult.get(),
                activeEnergyBurned: try? energyResult.get(),
                averageHeartRate: heartRateFigures?.average,
                maxHeartRate: heartRateFigures?.max
            ),
            sampleHeartRates: (try? sampleRatesResult.get()) ?? [:],
            complete: failures.isEmpty,
            failures: failures
        )
    }

    private static func attempt<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private static func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int? {
        let sumQuantity = try await fetchSum(for: HKQuantityType(.stepCount), from: startDate, to: endDate)
        return sumQuantity.map { Int($0.doubleValue(for: .count())) }
    }

    private static func fetchFlightsClimbed(from startDate: Date, to endDate: Date) async throws -> Int? {
        let sumQuantity = try await fetchSum(for: HKQuantityType(.flightsClimbed), from: startDate, to: endDate)
        return sumQuantity.map { Int($0.doubleValue(for: .count())) }
    }

    private static func fetchActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double? {
        let sumQuantity = try await fetchSum(for: HKQuantityType(.activeEnergyBurned), from: startDate, to: endDate)
        return sumQuantity?.doubleValue(for: .kilocalorie())
    }

    private static func fetchHeartRateStats(from startDate: Date, to endDate: Date) async throws -> (average: Double?, max: Double?) {
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

        // the outer optional is the timeout; the inner is HealthKit's "no statistics"
        guard let avgResult, let maxResult else { throw HealthQueryTimeout() }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let average = avgResult?.averageQuantity()?.doubleValue(for: heartRateUnit)
        let max = maxResult?.maximumQuantity()?.doubleValue(for: heartRateUnit)

        return (average: average, max: max)
    }

    // MARK: - Heart Rate for LocomotionSamples

    /// HealthKit heart rate readings matched to samples: to every sample at the same second, else to the
    /// nearest sample within 15 seconds. Where two readings match one sample, the later reading wins.
    nonisolated
    static func heartRates(from heartRateSamples: [HKQuantitySample], for locomotionSamples: [LocomotionSample]) -> [String: Double] {
        guard !heartRateSamples.isEmpty, !locomotionSamples.isEmpty else { return [:] }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

        let locomotionDict = Dictionary(grouping: locomotionSamples) { sample in
            return Date(timeIntervalSince1970: round(sample.date.timeIntervalSince1970))
        }

        var rates: [String: Double] = [:]

        for hrSample in heartRateSamples {
            let hrValue = hrSample.quantity.doubleValue(for: heartRateUnit)
            let hrDate = hrSample.startDate

            // try exact timestamp match first (rounded to nearest second)
            let roundedDate = Date(timeIntervalSince1970: round(hrDate.timeIntervalSince1970))
            if let exactMatches = locomotionDict[roundedDate] {
                for sample in exactMatches {
                    rates[sample.id] = hrValue
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
                rates[sample.id] = hrValue
            }
        }

        return rates
    }

    // MARK: - Public Fetching

    public static func heartRateSamples(for item: TimelineItem) async throws -> [HKQuantitySample] {
        guard healthKitEnabled else { return [] }
        guard let dateRange = item.dateRange else { return [] }
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        guard await UIApplication.shared.applicationState != .background else {
            throw TimelineError.backgroundRestriction
        }

        do {
            return try await fetchHeartRateSamples(from: dateRange.start, to: dateRange.end)
        } catch is HealthQueryTimeout {
            // as before BIG-963: the chart shows nothing rather than failing beside the sleep data
            print("HealthKit heart rate query timed out")
            return []
        }
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
        
        // a timeout is a failure, not "no data": the item stays unchecked (BIG-963)
        guard let statistics = result else { throw HealthQueryTimeout() }

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
        
        guard let samples = result else { throw HealthQueryTimeout() }

        return samples
    }

}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
