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
        migrator.registerMigration("source_indexes") { db in
            try? db.create(
                index: "TimelineItemBase_on_source",
                on: "TimelineItemBase",
                columns: ["source"]
            )
            
            try? db.create(
                index: "LocomotionSample_on_source",
                on: "LocomotionSample",
                columns: ["source"]
            )
        }
        
        migrator.registerMigration("Place.source") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "source", .text).notNull().defaults(to: "LocoKit2").indexed()
            }
        }
        
        migrator.registerMigration("TimelineItemBase_currentItem_index") { db in
            try? db.create(
                index: "TimelineItemBase_on_deleted_disabled_endDate",
                on: "TimelineItemBase",
                columns: ["deleted", "disabled", "endDate"]
            )
        }
        
        migrator.registerMigration("LocomotionSample_rtreeId_index") { db in
            try? db.create(
                index: "LocomotionSample_on_rtreeId",
                on: "LocomotionSample",
                columns: ["rtreeId"]
            )
        }
    }
}
