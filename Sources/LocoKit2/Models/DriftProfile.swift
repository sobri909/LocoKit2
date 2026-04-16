//
//  DriftProfile.swift
//  Arc Timeline
//
//  Created by Claude on 2026-04-15
//

import Foundation
import GRDB

public struct DriftProfile: FetchableRecord, PersistableRecord, Identifiable, Codable, Hashable, Sendable {

    public var id: String = UUID().uuidString
    public var lastSaved: Date = .now
    public var placeId: String?  // nil = generic/fallback profile

    public var excursionSampleCount: Int = 0

    // Spatial
    public var maxObservedDrift: Double = 0      // metres from place centroid
    public var meanDriftDistance: Double = 0      // metres

    // Direction - 8 sectors of 45 degrees, JSON TEXT in database
    public var directionHistogram: [Int] = Array(repeating: 0, count: 8)

    // Raw signal characteristics from excursion samples
    public var typicalSpeedMin: Double = 0
    public var typicalSpeedMax: Double = 0
    public var typicalHAccMin: Double = 0
    public var typicalHAccMax: Double = 0
    public var typicalVAccDuringDrift: Double?
    public var courseAvailability: Double = 0     // 0-1 fraction

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case lastSaved
        case placeId
        case excursionSampleCount
        case maxObservedDrift
        case meanDriftDistance
        case typicalSpeedMin
        case typicalSpeedMax
        case typicalHAccMin
        case typicalHAccMax
        case typicalVAccDuringDrift
        case courseAvailability
    }

    // MARK: - Columns

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let lastSaved = Column(CodingKeys.lastSaved)
        public static let placeId = Column(CodingKeys.placeId)
        public static let excursionSampleCount = Column(CodingKeys.excursionSampleCount)
        public static let maxObservedDrift = Column(CodingKeys.maxObservedDrift)
        public static let meanDriftDistance = Column(CodingKeys.meanDriftDistance)
        public static let directionHistogram = Column("directionHistogram")
        public static let typicalSpeedMin = Column(CodingKeys.typicalSpeedMin)
        public static let typicalSpeedMax = Column(CodingKeys.typicalSpeedMax)
        public static let typicalHAccMin = Column(CodingKeys.typicalHAccMin)
        public static let typicalHAccMax = Column(CodingKeys.typicalHAccMax)
        public static let typicalVAccDuringDrift = Column(CodingKeys.typicalVAccDuringDrift)
        public static let courseAvailability = Column(CodingKeys.courseAvailability)
    }

    public init() {}

    // MARK: - FetchableRecord

    public init(row: Row) throws {
        id = row["id"]
        lastSaved = row["lastSaved"]
        placeId = row["placeId"]
        excursionSampleCount = row["excursionSampleCount"]
        maxObservedDrift = row["maxObservedDrift"]
        meanDriftDistance = row["meanDriftDistance"]
        typicalSpeedMin = row["typicalSpeedMin"]
        typicalSpeedMax = row["typicalSpeedMax"]
        typicalHAccMin = row["typicalHAccMin"]
        typicalHAccMax = row["typicalHAccMax"]
        typicalVAccDuringDrift = row["typicalVAccDuringDrift"]
        courseAvailability = row["courseAvailability"]

        // directionHistogram: JSON-encoded [Int] in database
        let decoder = JSONDecoder()
        if let data = row["directionHistogram"] as? Data {
            directionHistogram = (try? decoder.decode([Int].self, from: data)) ?? Array(repeating: 0, count: 8)
        }
    }

    // MARK: - PersistableRecord

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["lastSaved"] = lastSaved
        container["placeId"] = placeId
        container["excursionSampleCount"] = excursionSampleCount
        container["maxObservedDrift"] = maxObservedDrift
        container["meanDriftDistance"] = meanDriftDistance
        container["typicalSpeedMin"] = typicalSpeedMin
        container["typicalSpeedMax"] = typicalSpeedMax
        container["typicalHAccMin"] = typicalHAccMin
        container["typicalHAccMax"] = typicalHAccMax
        container["typicalVAccDuringDrift"] = typicalVAccDuringDrift
        container["courseAvailability"] = courseAvailability

        // directionHistogram: JSON-encoded [Int] in database
        let encoder = JSONEncoder()
        container["directionHistogram"] = try? encoder.encode(directionHistogram)
    }

}
