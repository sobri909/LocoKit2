//
//  LegacySample.swift
//
//
//  Created by Matt Greenfield on 13/4/24.
//

import Foundation
import CoreLocation
import GRDB

public struct LegacySample: FetchableRecord, TableRecord, Identifiable, Codable, Hashable, Sendable {
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
}
