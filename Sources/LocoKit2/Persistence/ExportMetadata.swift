//
//  ExportMetadata.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2025-01-07.
//

import Foundation

public struct ExportMetadata: Codable, Sendable {
    let exportDate: Date
    let version: String  // LocoKit2 version at export time
    let stats: ExportStats
}

public struct ExportStats: Codable, Sendable {
    let placeCount: Int
    let itemCount: Int
    let sampleCount: Int
}
