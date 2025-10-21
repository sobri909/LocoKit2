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

        migrator.registerMigration("Place.lastVisitDate") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "lastVisitDate", .datetime)
            }
        }

        migrator.registerMigration("TimelineItemBase_visits_index") { db in
            try? db.create(
                index: "TimelineItemBase_on_isVisit_deleted_disabled_startDate",
                on: "TimelineItemBase",
                columns: ["isVisit", "deleted", "disabled", "startDate"]
            )
        }

        migrator.registerMigration("LocomotionSample.heartRate") { db in
            try? db.alter(table: "LocomotionSample") { table in
                table.add(column: "heartRate", .double)
            }
        }

        migrator.registerMigration("TimelineItemBase.locked") { db in
            try? db.alter(table: "TimelineItemBase") { table in
                table.add(column: "locked", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("disabled_state_auto_sync") { db in
            // drop old constraint triggers (existing beta testers have these from shipped builds)
            try? db.execute(sql: "DROP TRIGGER IF EXISTS LocomotionSample_BEFORE_INSERT_disabled_check")
            try? db.execute(sql: "DROP TRIGGER IF EXISTS LocomotionSample_BEFORE_UPDATE_disabled_check")
            try? db.execute(sql: "DROP TRIGGER IF EXISTS TimelineItemBase_BEFORE_UPDATE_disabled_check")

            // create auto-sync trigger: when item.disabled changes, cascade to all samples
            try? db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_disabled_sync
                AFTER UPDATE OF disabled ON TimelineItemBase
                WHEN NEW.disabled != OLD.disabled
                BEGIN
                    UPDATE LocomotionSample
                    SET disabled = NEW.disabled
                    WHERE timelineItemId = NEW.id;
                END;
                """)
        }
    }
}
