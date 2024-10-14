//
//  LocomotionSample.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import CoreLocation
@preconcurrency import GRDB

public struct LocomotionSample: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

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
    public var classifiedActivityType: ActivityType?
    public var confirmedActivityType: ActivityType?

    public var activityType: ActivityType? { confirmedActivityType ?? classifiedActivityType }

    // motion sensor data
    public var stepHz: Double?
    public var xyAcceleration: Double?
    public var zAcceleration: Double?

    public private(set) var location: CLLocation? = nil
    public var coordinate: CLLocationCoordinate2D? { location?.coordinate }
    public var hasUsableCoordinate: Bool { location?.hasUsableCoordinate ?? false }

    // TODO: hook this up
    public var sinceVisitStart: Double { return 0 }

    // rtree
    public var rtreeId: Int64?

    static let rtree = belongsTo(SampleRTree.self, using: ForeignKey(["rtreeId"]))

    // TODO: needs to us correct calendar based on secondsFromGMT
    public var timeOfDay: TimeInterval { date.sinceStartOfDay() }

    public var localTimeZone: TimeZone? { TimeZone(secondsFromGMT: secondsFromGMT) }

    // MARK: -

    internal var coreMLFeatureProvider: CoreMLFeatureProvider {
        return CoreMLFeatureProvider(
            stepHz: stepHz,
            xyAcceleration: xyAcceleration,
            zAcceleration: zAcceleration,
            movingState: movingState.stringValue,
            verticalAccuracy: location?.verticalAccuracy,
            horizontalAccuracy: location?.horizontalAccuracy,
            courseVariance: nil,
            speed: location?.speed,
            course: location?.course,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            altitude: location?.altitude,
            timeOfDay: timeOfDay,
            sinceVisitStart: sinceVisitStart
        )
    }

    // MARK: - Init

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

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.secondsFromGMT = try container.decode(Int.self, forKey: .secondsFromGMT)
        self.source = try container.decode(String.self, forKey: .source)
        self.sourceVersion = try container.decode(String.self, forKey: .sourceVersion)
        self.movingState = try container.decode(MovingState.self, forKey: .movingState)
        self.recordingState = try container.decode(RecordingState.self, forKey: .recordingState)
        self.disabled = try container.decode(Bool.self, forKey: .disabled)

        self.timelineItemId = try container.decodeIfPresent(String.self, forKey: .timelineItemId)

        self.latitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .longitude)
        self.altitude = try container.decodeIfPresent(CLLocationDistance.self, forKey: .altitude)
        self.horizontalAccuracy = try container.decodeIfPresent(CLLocationAccuracy.self, forKey: .horizontalAccuracy)
        self.verticalAccuracy = try container.decodeIfPresent(CLLocationAccuracy.self, forKey: .verticalAccuracy)
        self.speed = try container.decodeIfPresent(CLLocationSpeed.self, forKey: .speed)
        self.course = try container.decodeIfPresent(CLLocationDirection.self, forKey: .course)

        self.classifiedActivityType = try container.decodeIfPresent(ActivityType.self, forKey: .classifiedActivityType)
        self.confirmedActivityType = try container.decodeIfPresent(ActivityType.self, forKey: .confirmedActivityType)

        self.stepHz = try container.decodeIfPresent(Double.self, forKey: .stepHz)
        self.xyAcceleration = try container.decodeIfPresent(Double.self, forKey: .xyAcceleration)
        self.zAcceleration = try container.decodeIfPresent(Double.self, forKey: .zAcceleration)

        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.location = CLLocation(
                coordinate: coordinate, altitude: altitude!,
                horizontalAccuracy: horizontalAccuracy ?? -1,
                verticalAccuracy: verticalAccuracy ?? -1,
                course: course ?? -1, speed: speed ?? -1,
                timestamp: date
            )
        }
    }

    // MARK: -

    public var classifierResults: ClassifierResults? {
        get async {
            return await ActivityClassifier.highlander.results(for: self)
        }
    }

    // MARK: -

    internal mutating func saveRTree() async {
        guard let coordinate = location?.coordinate, coordinate.isUsable else { return }
        guard rtreeId == nil else { return }

        do {
            rtreeId = try await Database.pool.write { [self] db in
                var rtree = SampleRTree(
                    latMin: coordinate.latitude, latMax: coordinate.latitude,
                    lonMin: coordinate.longitude, lonMax: coordinate.longitude
                )
                try rtree.insert(db)

                var mutableSelf = self
                try mutableSelf.updateChanges(db) { sample in
                    sample.rtreeId = rtree.id
                }

                return rtree.id
            }

        } catch {
            logger.error(error, subsystem: .database)
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

    func dateRange() -> DateInterval? {
        let dates = map { $0.date }
        guard let start = dates.min(), let end = dates.max() else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}
