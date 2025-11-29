//
//  ExportMetadata.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation

public enum ExportMode: String, Codable, Sendable {
    case bucketed, singleFile
}

public enum ExportType: String, Codable, Sendable {
    case full
    case incremental
}

public struct ExportMetadata: Codable, Sendable {
    let schemaVersion: String
    let exportMode: ExportMode
    let exportType: ExportType
    
    let sessionStartDate: Date
    let sessionFinishDate: Date?
    
    let itemsCompleted: Bool
    let placesCompleted: Bool
    let samplesCompleted: Bool
    
    let stats: ExportStats

    // incremental backup tracking
    var lastBackupDate: Date?
    var extensions: [String: ExtensionState]?
}

public struct ExtensionState: Codable, Sendable {
    public var recordCount: Int

    public init(recordCount: Int) {
        self.recordCount = recordCount
    }
}

public struct ExportStats: Codable, Sendable {
    let placeCount: Int
    let itemCount: Int
    let sampleCount: Int
}
