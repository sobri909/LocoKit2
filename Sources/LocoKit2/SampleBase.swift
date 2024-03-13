//
//  SampleBase.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct SampleBase: Identifiable, Codable, FetchableRecord, PersistableRecord {

    public var id: String = UUID().uuidString
    public var date: Date
    public var secondsFromGMT: Int
    public var source: String = "LocoKit"
    public let movingState: MovingState
    public let recordingState: RecordingState

    // strings for now, until classifier stuff is ported over
    public var classifiedType: String?
    public var confirmedType: String?

    static let location = hasOne(SampleLocation.self).forKey("location")
    static let extended = hasOne(SampleExtended.self).forKey("extended")

    // MARK: -

    public init(date: Date, secondsFromGMT: Int = TimeZone.current.secondsFromGMT(), movingState: MovingState, recordingState: RecordingState) {
        self.date = date
        self.secondsFromGMT = secondsFromGMT
        self.movingState = movingState
        self.recordingState = recordingState
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.secondsFromGMT = try container.decode(Int.self, forKey: .secondsFromGMT)
        self.source = try container.decode(String.self, forKey: .source)
        self.movingState = try container.decode(MovingState.self, forKey: .movingState)
        self.recordingState = try container.decode(RecordingState.self, forKey: .recordingState)
        self.classifiedType = try? container.decode(String.self, forKey: .classifiedType)
        self.confirmedType = try? container.decode(String.self, forKey: .confirmedType)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(secondsFromGMT, forKey: .secondsFromGMT)
        try container.encode(source, forKey: .source)
        try container.encode(movingState, forKey: .movingState)
        try container.encode(recordingState, forKey: .recordingState)
        try container.encode(classifiedType, forKey: .classifiedType)
        try container.encode(confirmedType, forKey: .confirmedType)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case secondsFromGMT
        case source
        case movingState
        case recordingState
        case classifiedType
        case confirmedType
    }

    // MARK: - PersistableRecord

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source"] = source
        container["date"] = date
        container["secondsFromGMT"] = secondsFromGMT
        container["movingState"] = movingState.rawValue
        container["recordingState"] = recordingState.rawValue
        container["classifiedType"] = classifiedType
        container["confirmedType"] = confirmedType
    }

}
