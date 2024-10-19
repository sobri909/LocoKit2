//
//  Created by Matt Greenfield on 10/3/24.
//

import Foundation

extension Array {
    var second: Element? {
        guard count > 1 else { return nil }
        return self[1]
    }

    var secondToLast: Element? {
        guard count > 1 else { return nil }
        return self[count - 2]
    }

    var penultimate: Element? {
        return secondToLast
    }
}

extension Array where Element: BinaryFloatingPoint {
    func mean() -> Element {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Element(count)
    }

    func standardDeviation() -> Element {
        guard count > 1 else { return 0 }
        return meanAndStandardDeviation().standardDeviation
    }

    func meanAndStandardDeviation() -> (mean: Element, standardDeviation: Element) {
        guard !isEmpty else { return (0, 0) }
        let mean = self.mean()
        guard count > 1 else { return (mean, 0) }
        let sumOfSquaredDifferences = reduce(0) { $0 + (($1 - mean) * ($1 - mean)) }
        let standardDeviation = sqrt(sumOfSquaredDifferences / Element(count - 1))
        return (mean, standardDeviation)
    }
}

extension Array where Element: AdditiveArithmetic {
    func sum() -> Element {
        reduce(.zero, +)
    }
}

extension Array where Element: Hashable {
    func mode() -> Element? {
        return self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }.max(by: { $0.value < $1.value })?.key
    }
}

extension Comparable {
    mutating func clamp(min: Self, max: Self) {
        if self < min { self = min }
        if self > max { self = max }
    }

    func clamped(min: Self, max: Self) -> Self {
        if self < min { return min }
        if self > max { return max }
        return self
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

    func appendLineTo(_ url: URL) throws {
        try (self + "\n").appendTo(url)
    }

    func appendTo(_ url: URL) throws {
        let data = data(using: .utf8)!
        try data.appendTo(url)
    }
}

extension Data {
    func appendTo(_ url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url, options: .atomic)
        }
    }
}
