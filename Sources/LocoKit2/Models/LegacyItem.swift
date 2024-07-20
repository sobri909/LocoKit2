//
//  LegacyItem.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import GRDB

public struct LegacyItem: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {
    public static var databaseTableName: String { return "TimelineItem" }

    public var id: String { itemId }
    public var itemId: String = UUID().uuidString
    public let isVisit: Bool
    public let startDate: Date?
    public let endDate: Date?
    public var source: String = "LocoKit"
    public var deleted = false

    public var dateRange: DateInterval? {
        guard let startDate, let endDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }

    public var previousItemId: String? {
        didSet {
            if previousItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public var nextItemId: String? {
        didSet {
            if nextItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    // MARK: - Init

    init(from sample: LegacySample) {
        isVisit = sample.movingState == "stationary"
        startDate = sample.date
        endDate = sample.date
    }

    // MARK: - PersistableRecord

    public func encode(to container: inout PersistenceContainer) {
        container["itemId"] = itemId
        container["source"] = source
        container["isVisit"] = isVisit
        container["startDate"] = startDate
        container["endDate"] = endDate
        container["deleted"] = deleted
        container["lastSaved"] = Date()

        container["previousItemId"] = previousItemId
        container["nextItemId"] = nextItemId
    }

}
