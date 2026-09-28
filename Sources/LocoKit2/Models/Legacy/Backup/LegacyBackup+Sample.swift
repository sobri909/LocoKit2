//
//  LegacyBackup+Sample.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyBackup {

    /// One element of a `LocomotionSample/<week>.json.gz` array. Keys are old LocoKit's
    /// `LocomotionSample` encoder plus `PersistentSample`'s four (`timelineItemId`, `lastSaved`,
    /// `deleted`, `disabled`). `movingState` / `recordingState` are the old app's STRING enums
    /// (LocoKit2's are Int-backed, which is why `LocomotionSample: Codable` cannot read these
    /// files directly). `location` is an explicit null for a location-less sample, and
    /// `lastSaved` is written unconditionally, so it too can be null.
    public struct Sample: Codable, Hashable, Sendable {

        /// The old `CodableLocation`: all eight fields are always written together.
        public struct Location: Codable, Hashable, Sendable {
            public let latitude: Double
            public let longitude: Double
            public let altitude: Double
            public let horizontalAccuracy: Double
            public let verticalAccuracy: Double
            public let speed: Double
            public let course: Double
            public let timestamp: Date
        }

        // old LocoKit LocomotionSample
        public let sampleId: String
        public let date: Date
        public let secondsFromGMT: Int?
        public let location: Location?
        public let movingState: String
        public let recordingState: String
        public let stepHz: Double?
        public let courseVariance: Double?
        public let xyAcceleration: Double?
        public let zAcceleration: Double?
        public let confirmedType: String?
        public let classifiedType: String?

        // old LocoKit PersistentSample
        public let timelineItemId: String?
        public let lastSaved: Date?
        public let deleted: Bool?
        public let disabled: Bool?

        // MARK: -

        public var isDeleted: Bool { deleted ?? false }
        public var isDisabled: Bool { disabled ?? false }
    }
}
