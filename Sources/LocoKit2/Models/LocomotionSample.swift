//
//  LocomotionSample.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class LocomotionSample: Record, Identifiable, Codable {

    public var id: String = UUID().uuidString
    public var date: Date
    public var secondsFromGMT: Int
    public var source: String = "LocoKit"
    public let movingState: MovingState
    public let recordingState: RecordingState

    // foreign key
    public var timelineItemId: String?

    // CLLocation
    public let latitude: CLLocationDegrees?
    public let longitude: CLLocationDegrees?
    public let altitude: CLLocationDistance?
    public let horizontalAccuracy: CLLocationAccuracy?
    public let verticalAccuracy: CLLocationAccuracy?
    public let speed: CLLocationSpeed?
    public let course: CLLocationDirection?

    // strings for now, until classifier stuff is ported over
    public var classifiedActivityType: String?
    public var confirmedActivityType: String?

    // motion sensor data
    public var stepHz: Double?
    public var xyAcceleration: Double?
    public var zAcceleration: Double?

    @ObservationIgnored
    public lazy var coordinate: CLLocationCoordinate2D? = {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }()

    @ObservationIgnored
    public lazy var location: CLLocation? = {
        guard let coordinate else { return nil }
        return CLLocation(
            coordinate: coordinate, altitude: altitude!,
            horizontalAccuracy: horizontalAccuracy!,
            verticalAccuracy: verticalAccuracy!,
            course: course!, speed: speed!,
            timestamp: date
        )
    }()

    public override class var databaseTableName: String { return "LocomotionSample" }

    // MARK: -

    public init(
        date: Date, secondsFromGMT: Int = TimeZone.current.secondsFromGMT(),
        movingState: MovingState, recordingState: RecordingState,
        location: CLLocation? = nil
    ) {
        self.date = date
        self.secondsFromGMT = secondsFromGMT
        self.movingState = movingState
        self.recordingState = recordingState

        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.altitude = location?.altitude
        self.horizontalAccuracy = location?.horizontalAccuracy
        self.verticalAccuracy = location?.verticalAccuracy
        self.speed = location?.speed
        self.course = location?.course

        super.init()
    }

    required init(row: Row) throws {
        id = row["id"]
        date = row["date"]
        secondsFromGMT = row["secondsFromGMT"]
        source = row["source"]
        movingState = MovingState(rawValue: row["movingState"])!
        recordingState = RecordingState(rawValue: row["recordingState"])!

        timelineItemId = row["timelineItemId"]
        
        latitude = row["latitude"]
        longitude = row["longitude"]
        altitude = row["altitude"]
        horizontalAccuracy = row["horizontalAccuracy"]
        verticalAccuracy = row["verticalAccuracy"]
        speed = row["speed"]
        course = row["course"]

        classifiedActivityType = row["classifiedActivityType"]
        confirmedActivityType = row["confirmedActivityType"]
        
        stepHz = row["stepHz"]
        xyAcceleration = row["xyAcceleration"]
        zAcceleration = row["zAcceleration"]

        try super.init(row: row)
    }

    // MARK: - Record

    public override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["date"] = date
        container["secondsFromGMT"] = secondsFromGMT
        container["source"] = source
        container["movingState"] = movingState.rawValue
        container["recordingState"] = recordingState.rawValue

        container["timelineItemId"] = timelineItemId

        container["latitude"] = latitude
        container["longitude"] = longitude
        container["altitude"] = altitude
        container["horizontalAccuracy"] = horizontalAccuracy
        container["verticalAccuracy"] = verticalAccuracy
        container["speed"] = speed
        container["course"] = course

        container["classifiedActivityType"] = classifiedActivityType
        container["confirmedActivityType"] = confirmedActivityType
        
        container["stepHz"] = stepHz
        container["xyAcceleration"] = xyAcceleration
        container["zAcceleration"] = zAcceleration
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case secondsFromGMT
        case source
        case movingState
        case recordingState
        
        case timelineItemId

        case latitude 
        case longitude
        case  altitude
        case horizontalAccuracy
        case verticalAccuracy
        case speed
        case course

        case classifiedActivityType 
        case confirmedActivityType
        
        case stepHz
        case xyAcceleration
        case zAcceleration
    }

    required public init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: CodingKeys.id)
        self.date = try container.decode(Date.self, forKey: CodingKeys.date)
        self.secondsFromGMT = try container.decode(Int.self, forKey: CodingKeys.secondsFromGMT)
        self.source = try container.decode(String.self, forKey: CodingKeys.source)
        self.movingState = try container.decode(MovingState.self, forKey: CodingKeys.movingState)
        self.recordingState = try container.decode(RecordingState.self, forKey: CodingKeys.recordingState)
        self.timelineItemId = try container.decodeIfPresent(String.self, forKey: CodingKeys.timelineItemId)
        self.latitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: CodingKeys.latitude)
        self.longitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: CodingKeys.longitude)
        self.altitude = try container.decodeIfPresent(CLLocationDistance.self, forKey: CodingKeys.altitude)
        self.horizontalAccuracy = try container.decodeIfPresent(CLLocationAccuracy.self, forKey: CodingKeys.horizontalAccuracy)
        self.verticalAccuracy = try container.decodeIfPresent(CLLocationAccuracy.self, forKey: CodingKeys.verticalAccuracy)
        self.speed = try container.decodeIfPresent(CLLocationSpeed.self, forKey: CodingKeys.speed)
        self.course = try container.decodeIfPresent(CLLocationDirection.self, forKey: CodingKeys.course)
        self.classifiedActivityType = try container.decodeIfPresent(String.self, forKey: CodingKeys.classifiedActivityType)
        self.confirmedActivityType = try container.decodeIfPresent(String.self, forKey: CodingKeys.confirmedActivityType)
        self.stepHz = try container.decodeIfPresent(Double.self, forKey: CodingKeys.stepHz)
        self.xyAcceleration = try container.decodeIfPresent(Double.self, forKey: CodingKeys.xyAcceleration)
        self.zAcceleration = try container.decodeIfPresent(Double.self, forKey: CodingKeys.zAcceleration)

        super.init()
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.id, forKey: CodingKeys.id)
        try container.encode(self.date, forKey: CodingKeys.date)
        try container.encode(self.secondsFromGMT, forKey: CodingKeys.secondsFromGMT)
        try container.encode(self.source, forKey: CodingKeys.source)
        try container.encode(self.movingState, forKey: CodingKeys.movingState)
        try container.encode(self.recordingState, forKey: CodingKeys.recordingState)
        try container.encodeIfPresent(self.timelineItemId, forKey: CodingKeys.timelineItemId)
        try container.encodeIfPresent(self.latitude, forKey: CodingKeys.latitude)
        try container.encodeIfPresent(self.longitude, forKey: CodingKeys.longitude)
        try container.encodeIfPresent(self.altitude, forKey: CodingKeys.altitude)
        try container.encodeIfPresent(self.horizontalAccuracy, forKey: CodingKeys.horizontalAccuracy)
        try container.encodeIfPresent(self.verticalAccuracy, forKey: CodingKeys.verticalAccuracy)
        try container.encodeIfPresent(self.speed, forKey: CodingKeys.speed)
        try container.encodeIfPresent(self.course, forKey: CodingKeys.course)
        try container.encodeIfPresent(self.classifiedActivityType, forKey: CodingKeys.classifiedActivityType)
        try container.encodeIfPresent(self.confirmedActivityType, forKey: CodingKeys.confirmedActivityType)
        try container.encodeIfPresent(self.stepHz, forKey: CodingKeys.stepHz)
        try container.encodeIfPresent(self.xyAcceleration, forKey: CodingKeys.xyAcceleration)
        try container.encodeIfPresent(self.zAcceleration, forKey: CodingKeys.zAcceleration)
    }

}

// MARK: - Arrays

public extension Array where Element: LocomotionSample {
    func radius(from center: CLLocation) -> Radius {
        return compactMap { $0.location }.radius(from: center)
    }
}
