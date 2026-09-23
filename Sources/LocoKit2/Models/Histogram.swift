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

    /// Build from pre-computed bins. Lets a caller count a second population into an
    /// existing histogram's bin edges (e.g. the low-confidence overlay on a trip's speeds
    /// histogram, BIG-697) so the two line up bar for bar.
    public init(bins: [Bin]) {
        self.bins = bins
    }

    /// Counts `values` into this histogram's bin edges, returning a histogram with identical
    /// bins. Values outside the range are clamped into the first/last bin rather than dropped,
    /// so a second population wider than the first still shows up, pinned at the edges
    /// (the same treatment the trip charts give out-of-axis low-confidence points).
    public func counting(_ values: [Double]) -> Histogram {
        guard let first = bins.first, let width = binWidth, width > 0 else {
            return Histogram(bins: bins.map { Bin(start: $0.start, end: $0.end, count: values.count) })
        }
        var counts = Array(repeating: 0, count: bins.count)
        for value in values {
            // BIG-767: clamp in Double BEFORE converting. `Int(Double)` traps on NaN, ±inf, or
            // anything past Int.max — and a second population counted into bins built from a
            // near-constant first one (bin width a few ULPs wide) puts an ordinary 30 m/s at
            // ~1e19. That was a fatal on the trip details screen, 1.7.1 on iOS 27.
            let raw = (value - first.start) / width
            guard !raw.isNaN else { continue }
            let bucket = Int(min(max(raw, 0), Double(bins.count - 1)))
            counts[bucket] += 1
        }
        return Histogram(bins: zip(bins, counts).map { Bin(start: $0.start, end: $0.end, count: $1) })
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

    /// - Parameter maxBins: cap on the Freedman-Diaconis bin count. FD sizes bins from the IQR,
    ///   so a tight cluster inside a wide range (a flight's cruise speeds across 0-900 km/h) can
    ///   ask for ~90 bins; callers with a bounded display pass something smaller (BIG-697)
    public init?(values: [Double], maxBins: Int = Histogram.maxBins) {
        // BIG-767: a NaN or infinite value poisons min/max and every division below
        let values = values.filter { $0.isFinite }
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }

        // if all values are equal, create a single zero-width bin
        if minValue == maxValue {
            bins = [Bin(start: minValue, end: minValue, count: values.count)]
            return
        }

        let binCount = Self.numberOfBins(for: values, maxBins: maxBins)
        let binWidth = (maxValue - minValue) / Double(binCount)

        // create fixed array of empty bins
        var counts = Array(repeating: 0, count: binCount)
        
        // bucket values into bins
        for value in values {
            // clamp in Double before converting (BIG-767); the max value lands on binCount
            // and is folded into the last bin, as before
            let raw = (value - minValue) / binWidth
            guard raw.isFinite else { continue }
            let bucket = Int(min(max(raw, 0), Double(binCount - 1)))
            counts[bucket] += 1
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
        // Use bin width as floor when SD=0 (e.g., single-bin histograms where all data
        // is in one cluster), so the KDE still produces meaningful probabilities
        let binWidth = bins.first?.width ?? 1.0
        let h = max(binWidth, sd * pow(Double(totalCount), -1.0/3.0))

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

    /// Upper bound on bins. The Freedman–Diaconis width is IQR-driven, so a distribution whose
    /// middle half is near-identical (a mostly-stationary trip's sample speeds after a segments
    /// cleanup) yields a near-zero width and a bin count in the millions — `Array(repeating:count:)`
    /// then aborts (BIG-717 device crash, 2026-09-09). No chart can show more than a few dozen bins.
    public static let maxBins = 100

    private static func numberOfBins(for values: [Double], maxBins: Int) -> Int {
        let proposedWidth = computeBinWidth(for: values)
        guard let max = values.max(), let min = values.min() else { return 1 }
        let proposed = ceil((max - min) / proposedWidth)
        guard proposed.isFinite, proposed >= 1 else { return 1 }
        return Int(Swift.min(proposed, Double(Swift.max(maxBins, 1))))
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
