//
//  SampleRTree.swift
//  LocoKit
//
//  Created by Matt Greenfield on 16/11/22.
//

import Foundation
import GRDB

struct SampleRTree: MutablePersistableRecord, Codable {
    var id: Int64?
    var latMin: Double
    var latMax: Double
    var lonMin: Double
    var lonMax: Double

    mutating func didInsert(_ inserted: InsertionSuccess) {
        self.id = inserted.rowID
    }
}
