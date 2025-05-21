//
//  LegacySample.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import CoreLocation
import GRDB

public struct LegacySample: FetchableRecord, TableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {
    
    public static var databaseTableName: String { return "LocomotionSample" }

    public var id: String { sampleId }
    public var sampleId: String = UUID().uuidString
    public var date: Date
    public var secondsFromGMT: Int?
    public var source: String = "LocoKit"
    public let movingState: String
    public let recordingState: String
    public var deleted = false
    public var disabled = false
    
    // activity classification
    public var classifiedType: String?
    public var confirmedType: String?
    
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

    public var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var location: CLLocation? {
        guard let coordinate else { return nil }
        return CLLocation(
            coordinate: coordinate, altitude: altitude!,
            horizontalAccuracy: horizontalAccuracy!,
            verticalAccuracy: verticalAccuracy!,
            course: course!, speed: speed!,
            timestamp: date
        )
    }

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
    }

    // MARK: - PersistableRecord

    public func encode(to container: inout PersistenceContainer) {
        container["sampleId"] = sampleId
        container["date"] = date
        container["secondsFromGMT"] = secondsFromGMT
        container["source"] = source
        container["movingState"] = movingState
        container["recordingState"] = recordingState
        container["deleted"] = deleted
        container["disabled"] = disabled
        container["lastSaved"] = Date()
        
        container["classifiedType"] = classifiedType
        container["confirmedType"] = confirmedType

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
