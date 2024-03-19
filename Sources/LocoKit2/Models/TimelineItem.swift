//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import GRDB

public struct TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable {
    public let base: TimelineItemBase
    public let visit: TimelineItemVisit?
    public let trip: TimelineItemTrip?
    public let samples: [LocomotionSample]

    public var id: String { base.id }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool {
        return lhs.id == rhs.id
    }
}
