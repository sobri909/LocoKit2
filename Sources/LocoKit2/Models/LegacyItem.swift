//
//  LegacyItem.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import GRDB

@Observable
public class LegacyItem: Record, Identifiable, Codable {

    public var id: String = UUID().uuidString
    public let isVisit: Bool
    public let startDate: Date
    public let endDate: Date
    public var source: String = "LocoKit"
    public var deleted = false

    public var dateRange: DateInterval {
        return DateInterval(start: startDate, end: endDate)
    }

    public var previousItemId: String? {
        didSet {
            if previousItemId == id { fatalError("Can't link to self") }
            if previousItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public var nextItemId: String? {
        didSet {
            if nextItemId == id { fatalError("Can't link to self") }
            if nextItemId != nil, previousItemId == nextItemId {
                fatalError("Can't set previousItem and nextItem to the same item")
            }
        }
    }

    public override class var databaseTableName: String { return "TimelineItem" }

    // MARK: - Init

    init(from sample: LegacySample) {
        isVisit = sample.movingState == "stationary"
        startDate = sample.date
        endDate = sample.date
        super.init()
    }

    // MARK: - Record

    required init(row: Row) throws {
        id = row["id"]
        source = row["source"]
        isVisit = row["isVisit"]
        startDate = row["startDate"]
        endDate = row["endDate"]
        deleted = row["deleted"]

        previousItemId = row["previousItemId"]
        nextItemId = row["nextItemId"]

        try super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source"] = source
        container["isVisit"] = isVisit
        container["startDate"] = startDate
        container["endDate"] = endDate
        container["deleted"] = deleted

        container["previousItemId"] = previousItemId
        container["nextItemId"] = nextItemId
    }

}
