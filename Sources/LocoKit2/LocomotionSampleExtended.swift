//
//  LocomotionSampleExtended.swift
//
//
//  Created by Matt Greenfield on 13/3/24.
//

import Foundation
import GRDB

struct LocomotionSampleExtended: Codable, FetchableRecord, PersistableRecord {
    var sampleId: String
    var stepHz: Double?
    var courseVariance: Double?
    var xyAcceleration: Double?
    var zAcceleration: Double?
    var classifiedType: String?
    var confirmedType: String?

    static let base = belongsTo(LocomotionSampleBase.self, key: "sampleId")
}
