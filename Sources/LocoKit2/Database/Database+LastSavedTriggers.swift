//
//  Database+LastSavedTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addLastSavedTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial lastSaved triggers") { db in
            try Database.createTriggers(family: .lastSaved, in: db)
        }
    }

    // MARK: - Last Modified Date Triggers

    /** update lastSaved timestamps when rows change */

    static let lastSavedTriggers: [TriggerDefinition] = [
        TriggerDefinition(name: "Place_AFTER_UPDATE_lastSaved_UNCHANGED", table: "Place", family: .lastSaved, body: """
            AFTER UPDATE ON Place
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE Place SET lastSaved = CURRENT_TIMESTAMP
                WHERE id = NEW.id;
            END;
            """),

        TriggerDefinition(name: "TimelineItemBase_AFTER_UPDATE_lastSaved_UNCHANGED", table: "TimelineItemBase", family: .lastSaved, body: """
            AFTER UPDATE ON TimelineItemBase
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE TimelineItemBase SET lastSaved = CURRENT_TIMESTAMP
                WHERE id = NEW.id;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_AFTER_UPDATE_lastSaved_UNCHANGED", table: "LocomotionSample", family: .lastSaved, body: """
            AFTER UPDATE ON LocomotionSample
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE LocomotionSample SET lastSaved = CURRENT_TIMESTAMP
                WHERE id = NEW.id;
            END;
            """),

        // BIG-748: lost on every install by the TimelineItemVisit.nullableCoordinates rebuild
        // (2026-06 → 2026-09); restored by the schema_registry_repair migration.
        TriggerDefinition(name: "TimelineItemVisit_AFTER_UPDATE_lastSaved_UNCHANGED", table: "TimelineItemVisit", family: .lastSaved, body: """
            AFTER UPDATE ON TimelineItemVisit
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE TimelineItemVisit SET lastSaved = CURRENT_TIMESTAMP
                WHERE itemId = NEW.itemId;
            END;
            """),

        TriggerDefinition(name: "TimelineItemTrip_AFTER_UPDATE_lastSaved_UNCHANGED", table: "TimelineItemTrip", family: .lastSaved, body: """
            AFTER UPDATE ON TimelineItemTrip
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE TimelineItemTrip SET lastSaved = CURRENT_TIMESTAMP
                WHERE itemId = NEW.itemId;
            END;
            """),

        TriggerDefinition(name: "DriftProfile_AFTER_UPDATE_lastSaved_UNCHANGED", table: "DriftProfile", family: .lastSaved, body: """
            AFTER UPDATE ON DriftProfile
            WHEN NEW.lastSaved IS OLD.lastSaved
            BEGIN
                UPDATE DriftProfile SET lastSaved = CURRENT_TIMESTAMP WHERE id = NEW.id;
            END;
            """),
    ]
}
