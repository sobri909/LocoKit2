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
        
        migrator.registerMigration("TaskStatus") { db in
            try? db.create(table: "TaskStatus") { table in
                table.primaryKey("identifier", .text)
                table.column("state", .text).notNull()
                table.column("minimumDelay", .double).notNull()
                table.column("lastUpdated", .datetime).notNull()
                table.column("lastStarted", .datetime)
                table.column("lastExpired", .datetime)
                table.column("lastCompleted", .datetime)
            }
        }
        
        migrator.registerMigration("LocomotionSample.heartRate") { db in
            try? db.alter(table: "LocomotionSample") { table in
                table.add(column: "heartRate", .double)
            }
        }
        
        migrator.registerMigration("Place.countryCode") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "countryCode", .text).indexed()
            }
        }
        
        migrator.registerMigration("Place.locality") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "locality", .text).indexed()
            }
        }
    }
}
