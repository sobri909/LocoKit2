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
        public init(start: Double, end: Double, count: Int) {
            self.start = start
            self.end = end
            self.count = count
        }
        
        public let start: Double
        public let end: Double
        public let count: Int
        
        public var width: Double { end - start }
        public var middle: Double { start + (width / 2) }
    }

    // MARK: - Init

    /// placeholder for days with no data
    public init() {
        bins = []
    }

    public static func forTimeOfDay(dates: [Date], timeZone: TimeZone = .current) -> Histogram? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let timesOfDay = dates.map { $0.sinceStartOfDay(in: calendar) }
        return Histogram(values: timesOfDay)
    }

    public static func forDurations(intervals: [TimeInterval]) -> Histogram? {
        return Histogram(values: intervals)
    }

    public init?(values: [Double]) {
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }

        // if all values are equal, create a single zero-width bin
        if minValue == maxValue {
            bins = [Bin(start: minValue, end: minValue, count: values.count)]
            return
        }

        let binCount = Self.numberOfBins(for: values)
        let binWidth = (maxValue - minValue) / Double(binCount)

        // create fixed array of empty bins
        var counts = Array(repeating: 0, count: binCount)
        
        // bucket values into bins
        for value in values {
            var bucket = Int((value - minValue) / binWidth)

            // handle edge case where value exactly equals maxValue
            if bucket == binCount {
                bucket = binCount - 1
            }
            
            if bucket >= 0 && bucket < binCount {
                counts[bucket] += 1
            }
        }
        
        // create final bins with proper start/end/count
        bins = (0..<binCount).map { i in
            let start = minValue + (Double(i) * binWidth)
            let end = start + binWidth
            return Bin(start: start, end: end, count: counts[i])
        }
    }

    // MARK: -

    public var binWidth: Double? {
        return bins[safe: 0]?.width
    }

    public var totalCount: Int {
        bins.reduce(0) { $0 + $1.count }
    }

    public var maxCount: Int {
        bins.map(\.count).max() ?? 0
    }

    public var mostCommonBin: (start: Double, middle: Double, end: Double, count: Int)? {
        guard let maxBin = bins.max(by: { $0.count < $1.count }) else { return nil }
        return (maxBin.start, maxBin.middle, maxBin.end, count: maxBin.count)
    }

    public var valueRange: ClosedRange<Double>? {
        guard let first = bins.first, let last = bins.last else { return nil }
        return first.start ... last.end
    }

    /// Calculate a smoothed probability for the given value using kernel density estimation
    public func probability(for value: Double) -> Double? {
        guard !bins.isEmpty else { return nil }
        guard let range = valueRange, range.contains(value) else { return nil }

        // Estimate SD from bins
        let weightedSum = bins.reduce(0.0) { sum, bin -> Double in
            return sum + (bin.middle * Double(bin.count))
        }
        let mean = weightedSum / Double(totalCount)

        let weightedSqSum = bins.reduce(0.0) { sum, bin -> Double in
            let diff = bin.middle - mean
            return sum + (diff * diff * Double(bin.count))
        }
        let sd = sqrt(weightedSqSum / Double(totalCount - 1))

        // More conservative bandwidth for sparse data
        let h = sd * pow(Double(totalCount), -1.0/3.0)

        // Factor out the constant
        let gaussianConstant = 1.0 / sqrt(2 * .pi)

        // Calculate kernel contributions
        let kernelContributions = bins.map { bin -> Double in
            let z = (value - bin.middle) / h
            return Double(bin.count) * exp(-0.5 * z * z) * gaussianConstant
        }

        let kernelSum = kernelContributions.reduce(0, +)
        let normalizationFactor = Double(totalCount) * gaussianConstant

        return kernelSum / normalizationFactor
    }

    // MARK: - FD calc

    private static func numberOfBins(for values: [Double]) -> Int {
        let proposedWidth = computeBinWidth(for: values)
        guard let max = values.max(), let min = values.min() else { return 1 }
        return Int(ceil((max - min) / proposedWidth))
    }

    private static func computeBinWidth(for values: [Double]) -> Double {
        guard values.count > 1 else { return 1.0 } // sensible default depends on usage

        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        let iqr = sorted[q3Index] - sorted[q1Index]

        let width = 2.0 * iqr * pow(Double(values.count), -1.0/3.0)
        
        // ensure we never return zero to prevent division by zero
        return width > 0 ? width : 1.0
    }

}
