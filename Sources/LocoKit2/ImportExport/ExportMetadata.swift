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
    let exportId: String?  // unique identifier for this export (nil for legacy exports)
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
    public var lastBackupDate: Date?
    public var backupProgressDate: Date?  // for first-run catch-up (tracks how far we've gotten)
    public var extensions: [String: ExtensionState]?

    // app-specific metadata (passthrough from app layer)
    public var appMetadata: [String: String]?
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
