//
//  Created by Matt Greenfield on 22/4/24.
//

import Foundation

// MARK: - Public

public extension TimeInterval {
    static func minutes(_ minutes: Int) -> TimeInterval { 60.0 * Double(minutes) }
    static func hours(_ hours: Int) -> TimeInterval { .minutes(60) * Double(hours) }
    static func days(_ days: Int) -> TimeInterval { .hours(24) * Double(days) }
    var unit: Measurement<UnitDuration> { Measurement(value: self, unit: UnitDuration.seconds) }
}

public extension Date {
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

    static func -(lhs: Date, rhs: Date) -> TimeInterval { lhs.timeIntervalSince(rhs) }
}

public extension Calendar {
    func previousDay(from date: Date) -> Date { self.date(byAdding: .day, value: -1, to: date)! }
    func nextDay(from date: Date) -> Date { self.date(byAdding: .day, value: 1, to: date)! }
}

// MARK: - Internal

extension DateInterval {
    var range: ClosedRange<Date> { start...end }
    func contains(_ other: DateInterval) -> Bool { self.start <= other.start && self.end >= other.end }
}
