//
//  TimelineItem+Strings.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 23/12/2024.
//

import Foundation

extension TimelineItem {

    public var typeString: String {
        get throws {
            if try isDataGap { return "datagap" }
            if try isNolo    { return "nolo" }
            if isVisit       { return "visit" }
            return "trip"
        }
    }

    public var title: String {
        get throws {
            if try isDataGap {
                return "Data Gap"
            }

            if let trip {
                if let activityType = trip.activityType {
                    return activityType.displayName.capitalized
                }
                return "Transport"
            }

            // must be a visit
            if let place {
                return place.name
            }

            if try isWorthKeeping {
                return "Unknown Place"
            }

            return "Brief Stop"
        }
    }

    public var description: String {
        get throws {
            String(format: "%@ %@", try keepnessString, try typeString)
        }
    }

    public func startString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let startDate = dateRange?.start else { return nil }
        return Self.dateString(
            for: startDate,
            timeZone: startTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative
        )
    }

    public func endString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let endDate = dateRange?.end else { return nil }
        return Self.dateString(
            for: endDate,
            timeZone: endTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative
        )
    }

    public static func dateString(for date: Date, timeZone: TimeZone = TimeZone.current, dateStyle: DateFormatter.Style = .none,
                                  timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        dateFormatter.timeZone = timeZone
        dateFormatter.doesRelativeDateFormatting = relative
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string(from: date)
    }

    static let dateFormatter = DateFormatter()

}