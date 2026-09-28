//
//  LegacyBackup+Note.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyBackup {

    /// One `Note/<prefix>/<noteId>.json` file, from Arc's `Note.encode`. Old notes are a single
    /// instant (`date`), not a range, and were never linked to a timeline item in the file.
    public struct Note: Codable, Hashable, Sendable {
        public let noteId: String
        public let date: Date
        public let body: String
        public let deleted: Bool?
        public let lastSaved: Date?

        public var isDeleted: Bool { deleted ?? false }
    }
}
