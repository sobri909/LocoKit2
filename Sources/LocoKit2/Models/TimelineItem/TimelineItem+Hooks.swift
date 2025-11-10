//
//  TimelineItem+Hooks.swift
//  LocoKit2
//
//  Created by Claude on 10/11/24.
//

import Foundation
import GRDB

extension TimelineItem {

    // MARK: - Merge hooks

    /// Called during merge transaction before updates are applied.
    /// - Parameters:
    ///   - keeper: The surviving item
    ///   - consumed: All items being consumed (may include betweener and deadman)
    ///   - db: Database connection for atomic operations
    nonisolated(unsafe) public static var onItemMerge: ((TimelineItem, Set<TimelineItem>, GRDB.Database) throws -> Void)?

}
