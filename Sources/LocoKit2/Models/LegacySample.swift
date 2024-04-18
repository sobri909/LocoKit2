//
//  LegacySample.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import CoreLocation
import GRDB

@Observable
public class LegacySample: Record, Identifiable, Codable {
    
    public var id: String = UUID().uuidString
    public var date: Date
    public var secondsFromGMT: Int?
    public var source: String = "LocoKit"
    public let movingState: String
    public let recordingState: String
    public var deleted = false

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
        self.movingState = movingState.stringValue
        self.recordingState = recordingState.stringValue

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
        movingState = row["movingState"]
        recordingState = row["recordingState"]

        timelineItemId = row["timelineItemId"]

        latitude = row["latitude"]
        longitude = row["longitude"]
        altitude = row["altitude"]
        horizontalAccuracy = row["horizontalAccuracy"]
        verticalAccuracy = row["verticalAccuracy"]
        speed = row["speed"]
        course = row["course"]

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
        container["movingState"] = movingState
        container["recordingState"] = recordingState

        container["timelineItemId"] = timelineItemId

        container["latitude"] = latitude
        container["longitude"] = longitude
        container["altitude"] = altitude
        container["horizontalAccuracy"] = horizontalAccuracy
        container["verticalAccuracy"] = verticalAccuracy
        container["speed"] = speed
        container["course"] = course

        container["stepHz"] = stepHz
        container["xyAcceleration"] = xyAcceleration
        container["zAcceleration"] = zAcceleration
    }

}
