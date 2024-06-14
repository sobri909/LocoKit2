//
//  LocomotionSample.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct LocomotionSample: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable {

    public private(set) var id: String = UUID().uuidString
    
    public var date: Date
    public var secondsFromGMT: Int
    public var source: String = "LocoKit"
    public var sourceVersion: String = LocomotionManager.locoKitVersion
    public let movingState: MovingState
    public let recordingState: RecordingState
    public var disabled = false

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

    public private(set) var location: CLLocation? = nil
    public var coordinate: CLLocationCoordinate2D? { location?.coordinate }

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

        self.location = location
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.altitude = location?.altitude
        self.horizontalAccuracy = location?.horizontalAccuracy
        self.verticalAccuracy = location?.verticalAccuracy
        self.speed = location?.speed
        self.course = location?.course
    }

    public init(row: Row) throws {
        id = row["id"]
        date = row["date"]
        secondsFromGMT = row["secondsFromGMT"]
        source = row["source"]
        sourceVersion = row["sourceVersion"]
        movingState = MovingState(rawValue: row["movingState"])!
        recordingState = RecordingState(rawValue: row["recordingState"])!
        disabled = row["disabled"]

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

        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            location = CLLocation(
                coordinate: coordinate, altitude: altitude!,
                horizontalAccuracy: horizontalAccuracy ?? -1,
                verticalAccuracy: verticalAccuracy ?? -1,
                course: course ?? -1, speed: speed ?? -1,
                timestamp: date
            )
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case secondsFromGMT
        case source
        case sourceVersion
        case movingState
        case recordingState
        case disabled

        case timelineItemId

        case latitude 
        case longitude
        case altitude
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

}

// MARK: - Arrays

public extension Array where Element == LocomotionSample {
    func radius(from center: CLLocation) -> Radius {
        return compactMap { $0.location }.radius(from: center)
    }
}
