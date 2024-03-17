//
//  SampleExtended.swift
//
//
//  Created by Matt Greenfield on 13/3/24.
//

import Foundation
import GRDB

public struct SampleExtended: Codable, FetchableRecord, PersistableRecord {
    public let sampleId: String
    public var stepHz: Double?
    public var xyAcceleration: Double?
    public var zAcceleration: Double?

    public static let base = belongsTo(SampleBase.self, key: "sampleId")
}
