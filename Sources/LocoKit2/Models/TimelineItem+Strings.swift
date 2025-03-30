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

    /// A descriptive title for the timeline item.
    /// - Returns: The item's title string.
    /// - Note: Will return "Error" if called on an item without loaded samples.
    public var title: String {
        do {
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
            if let visit, let customTitle = visit.customTitle {
                return customTitle
            }
            
            if let place {
                return place.name
            }

            if try isWorthKeeping {
                return "Unknown Place"
            }

            return "Brief Stop"
            
        } catch {
            logger.error(error, subsystem: .timeline)
            return "Error"
        }
    }

    public var description: String {
        get throws {
            String(format: "%@ %@", try keepnessString, try typeString)
        }
    }

    public func startString(
        dateStyle: DateFormatter.Style = .none,
        timeStyle: DateFormatter.Style = .short,
        relative: Bool = false,
        format: String? = nil) -> String?
    {
        guard let startDate = dateRange?.start else { return nil }
        return Self.dateString(
            for: startDate,
            timeZone: startTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative,
            format: format
        )
    }

    public func endString(
        dateStyle: DateFormatter.Style = .none,
        timeStyle: DateFormatter.Style = .short,
        relative: Bool = false,
        format: String? = nil) -> String?
    {
        guard let endDate = dateRange?.end else { return nil }
        return Self.dateString(
            for: endDate,
            timeZone: endTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative
        )
    }

    public static func dateString(
        for date: Date,
        timeZone: TimeZone? = nil,
        dateStyle: DateFormatter.Style = .none,
        timeStyle: DateFormatter.Style = .short,
        relative: Bool = false,
        format: String? = nil) -> String?
    {
        dateFormatter.timeZone = timeZone ?? .current
        dateFormatter.doesRelativeDateFormatting = relative
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        
        if let format {
            let oldFormat = dateFormatter.dateFormat
            dateFormatter.dateFormat = format
            let result = dateFormatter.string(from: date)
            dateFormatter.dateFormat = oldFormat
            return result

        } else {
            return dateFormatter.string(from: date)
        }
    }

    static let dateFormatter = DateFormatter()

}
