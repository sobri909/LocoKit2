//
//  PlaceRTree.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-10-25.
//

import Foundation
import GRDB

public struct PlaceRTree: MutablePersistableRecord, Codable, Sendable {
    public var id: Int64?
    public var latMin: Double
    public var latMax: Double
    public var lonMin: Double
    public var lonMax: Double

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        self.id = inserted.rowID
    }
}
