//
//  Database+LastSavedTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addLastSavedTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial triggers") { db in
            /** update lastSaved timestamps when rows change */

            try db.execute(sql: """
                CREATE TRIGGER Place_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON Place
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE Place SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON TimelineItemBase
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE TimelineItemBase SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER LocomotionSample_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON LocomotionSample
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE LocomotionSample SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemVisit_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON TimelineItemVisit
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE TimelineItemVisit SET lastSaved = CURRENT_TIMESTAMP
                    WHERE itemId = NEW.itemId;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemTrip_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON TimelineItemTrip
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE TimelineItemTrip SET lastSaved = CURRENT_TIMESTAMP
                    WHERE itemId = NEW.itemId;
                END;
                """)
        }
    }
}
