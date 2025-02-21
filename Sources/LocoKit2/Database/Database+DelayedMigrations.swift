//
//  Database+DelayedMigrations.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import Foundation
import GRDB

extension Database {
    public func addDelayedMigrations(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Place.occupancyTimes") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "occupancyTimes", .blob).notNull().defaults(to: Data())
            }
        }
    }
}
