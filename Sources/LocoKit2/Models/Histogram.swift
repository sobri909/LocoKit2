//
//  Histogram.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 02/11/2024.
//

import Foundation

public struct Histogram: Hashable, Sendable, Codable {

    public let bins: [Bin]

    public struct Bin: Hashable, Sendable, Codable {
        public let start: Double
        public let count: Int
    }

    // MARK: - Init

    public static func forTimeOfDay(dates: [Date], timeZone: TimeZone = .current) -> Histogram? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let timesOfDay = dates.map { $0.sinceStartOfDay(in: calendar) }
        return Histogram(values: timesOfDay, minimumBinWidth: 60.0) // minimum 1 minute bins
    }

    public static func forDurations(intervals: [TimeInterval]) -> Histogram? {
        return Histogram(values: intervals, minimumBinWidth: 60.0)
    }

    public init?(values: [Double], minimumBinWidth: Double? = nil) {
        if values.isEmpty { return nil }

        var binWidth = Self.computeBinWidth(for: values)
        if let minimumBinWidth {
            binWidth = max(binWidth, minimumBinWidth)
        }

        // create bins
        var counts: [Double: Int] = [:]
        for value in values {
            let binStart = floor(value / binWidth) * binWidth
            counts[binStart, default: 0] += 1
        }

        bins = counts.map { Bin(start: $0.key, count: $0.value) }
            .sorted { $0.start < $1.start }
    }

    // MARK: -

    public var binWidth: Double? {
        guard bins.count >= 2 else { return nil }
        return bins[1].start - bins[0].start
    }

    public var totalCount: Int {
        bins.reduce(0) { $0 + $1.count }
    }

    public var mostCommonBin: (start: Double, end: Double, count: Int)? {
        guard let maxBin = bins.max(by: { $0.count < $1.count }),
              let binWidth = binWidth else { return nil }
        return (maxBin.start, maxBin.start + binWidth, maxBin.count)
    }

    /// Calculate a smoothed probability for the given value using kernel density estimation
    public func probability(for value: Double) -> Double? {
        guard let binWidth, !bins.isEmpty else { return nil }

        // Estimate SD from bins
        let weightedSum = bins.reduce(0.0) { sum, bin -> Double in
            let binCenter = bin.start + binWidth / 2
            return sum + (binCenter * Double(bin.count))
        }
        let mean = weightedSum / Double(totalCount)

        let weightedSqSum = bins.reduce(0.0) { sum, bin -> Double in
            let binCenter = bin.start + binWidth / 2
            let diff = binCenter - mean
            return sum + (diff * diff * Double(bin.count))
        }
        let sd = sqrt(weightedSqSum / Double(totalCount - 1))

        // More conservative bandwidth for sparse data
        let h = sd * pow(Double(totalCount), -1.0/3.0)

        // Factor out the constant
        let gaussianConstant = 1.0 / sqrt(2 * .pi)

        // Calculate kernel contributions
        let kernelContributions = bins.map { bin -> Double in
            let binCenter = bin.start + binWidth / 2
            let z = (value - binCenter) / h
            return Double(bin.count) * exp(-0.5 * z * z) * gaussianConstant
        }

        let kernelSum = kernelContributions.reduce(0, +)
        let normalizationFactor = Double(totalCount) * gaussianConstant

        return kernelSum / normalizationFactor
    }

    // MARK: - FD calc

    private static func computeBinWidth(for values: [Double]) -> Double {
        guard values.count > 1 else { return 1.0 } // sensible default depends on usage

        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        let iqr = sorted[q3Index] - sorted[q1Index]

        return 2.0 * iqr * pow(Double(values.count), -1.0/3.0)
    }

}
