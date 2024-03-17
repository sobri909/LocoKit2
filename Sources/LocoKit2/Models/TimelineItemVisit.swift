//
//  TimelineItemVisit.swift
//  
//
//  Created by Matt Greenfield on 16/3/24.
//

import Foundation
import GRDB

public struct TimelineItemVisit: Codable, FetchableRecord, PersistableRecord {
    public let itemId: String
}
