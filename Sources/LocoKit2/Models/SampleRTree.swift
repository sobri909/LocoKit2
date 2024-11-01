//
//  SampleRTree.swift
//  LocoKit
//
//  Created by Matt Greenfield on 16/11/22.
//

import Foundation
import GRDB

public struct SampleRTree: MutablePersistableRecord, Codable, Sendable {
    public var id: Int64?
    public var latMin: Double
    public var latMax: Double
    public var lonMin: Double
    public var lonMax: Double

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        self.id = inserted.rowID
    }
}
