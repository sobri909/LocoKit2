//
//  Histogram.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 02/11/2024.
//

import Foundation

public struct Histogram: Hashable, Sendable, Codable {

    private let bins: [Bin]

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

        // Start with 2x binWidth for bandwidth - we can tune this
        let h = binWidth * 2

        // Sum up Gaussian kernel contributions from each bin
        let kernelSum = bins.reduce(0.0) { sum, bin in
            // Use bin center as the reference point
            let binCenter = bin.start + binWidth / 2
            let z = (value - binCenter) / h

            // Weight by bin count and calculate Gaussian
            let kernel = Double(bin.count) * exp(-0.5 * z * z) / sqrt(2 * .pi)
            return sum + kernel
        }

        // Normalize by total area
        return kernelSum / (Double(totalCount) * h)
    }

    public var binWidth: Double? {
        guard bins.count >= 2 else { return nil }
        return bins[1].start - bins[0].start
    }

    private static func computeBinWidth(for values: [Double]) -> Double {
        guard values.count > 1 else { return 1.0 } // sensible default depends on usage

        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        let iqr = sorted[q3Index] - sorted[q1Index]

        return 2.0 * iqr * pow(Double(values.count), -1.0/3.0)
    }

    private struct Bin: Hashable, Sendable, Codable {
        let start: Double
        let count: Int
    }

    // MARK: - Type specific inits

    public static func forTimeOfDay(dates: [Date], timeZone: TimeZone = .current) -> Histogram? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let timesOfDay = dates.map { $0.sinceStartOfDay(in: calendar) }
        return Histogram(values: timesOfDay, minimumBinWidth: 60.0) // minimum 1 minute bins
    }
    
    public static func forDurations(intervals: [TimeInterval]) -> Histogram? {
        return Histogram(values: intervals, minimumBinWidth: 60.0)
    }

}
