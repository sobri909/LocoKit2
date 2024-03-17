//
//  TimelineItemTrip.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import GRDB

public struct TimelineItemTrip: Codable, FetchableRecord, PersistableRecord {
    public let itemId: String
}
