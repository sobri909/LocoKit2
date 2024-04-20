//
//  Created by Matt Greenfield on 10/3/24.
//

import Foundation

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

extension TimeInterval {
    static func minutes(_ minutes: Int) -> TimeInterval {
        return 60.0 * Double(minutes)
    }

    static func hours(_ hours: Int) -> TimeInterval {
        return .minutes(60) * Double(hours)
    }

    static func days(_ days: Int) -> TimeInterval {
        return .hours(24) * Double(days)
    }

    var unit: Measurement<UnitDuration> {
        return Measurement(value: self, unit: UnitDuration.seconds)
    }
}

func withContinousObservation<T>(of value: @escaping @autoclosure () -> T, execute: @escaping (T) -> Void) {
    withObservationTracking {
        execute(value())
    } onChange: {
        Task { @MainActor in
            withContinousObservation(of: value(), execute: execute)
        }
    }
}

extension Date {
    var age: TimeInterval { return -timeIntervalSinceNow }

    func isToday(in calendar: Calendar = Calendar.current) -> Bool { calendar.isDateInToday(self) }
    func isYesterday(in calendar: Calendar = Calendar.current) -> Bool { calendar.isDateInYesterday(self) }
    func isTomorrow(in calendar: Calendar = Calendar.current) -> Bool { calendar.isDateInTomorrow(self) }

    func startOfDay(in calendar: Calendar = Calendar.current) -> Date { calendar.startOfDay(for: self) }
    func middleOfDay(in calendar: Calendar = Calendar.current) -> Date { startOfDay(in: calendar) + .hours(12) } // approximation
    func endOfDay(in calendar: Calendar = Calendar.current) -> Date { nextDay(in: calendar).startOfDay(in: calendar) }

    func sinceStartOfDay(in calendar: Calendar = Calendar.current) -> TimeInterval { timeIntervalSince(startOfDay(in: calendar)) }
    func dayOfMonth(in calendar: Calendar = Calendar.current) -> Int { calendar.component(.day, from: self) }

    func nextDay(in calendar: Calendar = Calendar.current) -> Date { calendar.nextDay(from: self) }
    func previousDay(in calendar: Calendar = Calendar.current) -> Date { calendar.previousDay(from: self) }

    func subtracting(days: Int, in calendar: Calendar = Calendar.current) -> Date { calendar.date(byAdding: .day, value: -days, to: self)! }
    func adding(days: Int, in calendar: Calendar = Calendar.current) -> Date { calendar.date(byAdding: .day, value: days, to: self)! }

    func isSameDayAs(_ date: Date, in calendar: Calendar = Calendar.current) -> Bool { calendar.isDate(date, inSameDayAs: self) }
    func isSameMonthAs(_ date: Date, in calendar: Calendar = Calendar.current) -> Bool { calendar.isDate(date, equalTo: self, toGranularity: .month) }

    static func -(lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSince(rhs)
    }
}

extension Calendar {
    func previousDay(from date: Date) -> Date { self.date(byAdding: .day, value: -1, to: date)! }
    func nextDay(from date: Date) -> Date { self.date(byAdding: .day, value: 1, to: date)! }
}

extension DateInterval {
    var range: ClosedRange<Date> { start...end }
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
