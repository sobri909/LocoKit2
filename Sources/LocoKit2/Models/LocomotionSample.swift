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

}
