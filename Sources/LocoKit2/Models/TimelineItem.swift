//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import GRDB

public struct TimelineItem: Identifiable, Decodable, FetchableRecord {
    public let base: TimelineItemBase
    public let visit: TimelineItemVisit?
    public let trip: TimelineItemTrip?
    public let samples: [LocomotionSample]

    public var id: String { base.id }
}
