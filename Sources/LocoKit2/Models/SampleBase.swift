//
//  SampleBase.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class SampleBase: Record, Identifiable, Codable {

    public var id: String = UUID().uuidString
    public var date: Date
    public var secondsFromGMT: Int
    public var source: String = "LocoKit"
    public let movingState: MovingState
    public let recordingState: RecordingState
    public var timelineItemId: String?

    // strings for now, until classifier stuff is ported over
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?

    public static let location = hasOne(SampleLocation.self).forKey("location")
    public static let extended = hasOne(SampleExtended.self).forKey("extended")

    public override class var databaseTableName: String { return "SampleBase" }

    // MARK: -

    public init(date: Date, secondsFromGMT: Int = TimeZone.current.secondsFromGMT(), movingState: MovingState, recordingState: RecordingState) {
        self.date = date
        self.secondsFromGMT = secondsFromGMT
        self.movingState = movingState
        self.recordingState = recordingState
        super.init()
    }

    required init(row: Row) throws {
        id = row["id"]
        date = row["date"]
        secondsFromGMT = row["secondsFromGMT"]
        source = row["source"]
        movingState = MovingState(rawValue: row["movingState"])!
        recordingState = RecordingState(rawValue: row["recordingState"])!
        classifiedActivityType = row["classifiedActivityType"]
        confirmedActivityType = row["confirmedActivityType"]
        timelineItemId = row["timelineItemId"]
        try super.init(row: row)
    }

    // MARK: - Record

    public override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source"] = source
        container["date"] = date
        container["secondsFromGMT"] = secondsFromGMT
        container["movingState"] = movingState.rawValue
        container["recordingState"] = recordingState.rawValue
        container["classifiedActivityType"] = classifiedActivityType
        container["confirmedActivityType"] = confirmedActivityType
        container["timelineItemId"] = timelineItemId
    }

}
