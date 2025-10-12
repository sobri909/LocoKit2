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

        migrator.registerMigration("disabled_state_constraint") { db in
            // prevent inserting sample with mismatched disabled state
            try? db.execute(sql: """
                CREATE TRIGGER LocomotionSample_BEFORE_INSERT_disabled_check
                BEFORE INSERT ON LocomotionSample
                WHEN NEW.timelineItemId IS NOT NULL
                BEGIN
                    SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase
                        WHERE id = NEW.timelineItemId
                        AND disabled != NEW.disabled
                    );
                END;
                """)

            // prevent updating sample to create mismatched disabled state
            try? db.execute(sql: """
                CREATE TRIGGER LocomotionSample_BEFORE_UPDATE_disabled_check
                BEFORE UPDATE OF disabled, timelineItemId ON LocomotionSample
                WHEN NEW.timelineItemId IS NOT NULL
                BEGIN
                    SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase
                        WHERE id = NEW.timelineItemId
                        AND disabled != NEW.disabled
                    );
                END;
                """)

            // prevent updating item disabled state if samples have different disabled state
            try? db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_UPDATE_disabled_check
                BEFORE UPDATE OF disabled ON TimelineItemBase
                WHEN NEW.disabled != OLD.disabled
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot change item disabled state when samples have different disabled state')
                    WHERE EXISTS (
                        SELECT 1 FROM LocomotionSample
                        WHERE timelineItemId = NEW.id
                        AND disabled != NEW.disabled
                    );
                END;
                """)
        }
    }
}
