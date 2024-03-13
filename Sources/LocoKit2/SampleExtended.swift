//
//  SampleExtended.swift
//
//
//  Created by Matt Greenfield on 13/3/24.
//

import Foundation
import GRDB

struct SampleExtended: Codable, FetchableRecord, PersistableRecord {
    var sampleId: String
    var stepHz: Double?
    var courseVariance: Double?
    var xyAcceleration: Double?
    var zAcceleration: Double?

    static let base = belongsTo(SampleBase.self, key: "sampleId")
}
