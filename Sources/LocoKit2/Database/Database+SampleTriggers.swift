//
//  Database+SampleTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addSampleTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial sample triggers") { db in
            try Database.createTriggers(family: .sampleDates, in: db)
        }
    }

    // MARK: - Item date range + dirty flag maintenance

    static let sampleDateTriggers: [TriggerDefinition] = [
        TriggerDefinition(name: "LocomotionSample_AFTER_INSERT_timelineItemId_SET", table: "LocomotionSample", family: .sampleDates, body: """
            AFTER INSERT ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL
            BEGIN
                UPDATE TimelineItemBase
                    SET startDate = CASE
                        WHEN startDate IS NULL THEN NEW.date
                        ELSE MIN(startDate, NEW.date)
                    END,
                    endDate = CASE
                        WHEN endDate IS NULL THEN NEW.date
                        ELSE MAX(endDate, NEW.date)
                    END,
                    samplesChanged = 1
                WHERE id = NEW.timelineItemId;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_AFTER_UPDATE_timelineItemId_SET", table: "LocomotionSample", family: .sampleDates, body: """
            AFTER UPDATE OF timelineItemId ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL AND OLD.timelineItemId IS NOT NEW.timelineItemId
            BEGIN
                UPDATE TimelineItemBase
                    SET startDate = CASE
                        WHEN startDate IS NULL THEN NEW.date
                        ELSE MIN(startDate, NEW.date)
                    END,
                    endDate = CASE
                        WHEN endDate IS NULL THEN NEW.date
                        ELSE MAX(endDate, NEW.date)
                    END,
                    samplesChanged = 1
                WHERE id = NEW.timelineItemId;
            END;
            """),

        // Recomputes MIN/MAX over the remaining samples, so the LAST sample leaving an item
        // NULLs its dates (moves empty the range; DELETEs do not fire this and fossilise it).
        TriggerDefinition(name: "LocomotionSample_AFTER_UPDATE_timelineItemId_UNSET", table: "LocomotionSample", family: .sampleDates, body: """
            AFTER UPDATE OF timelineItemId ON LocomotionSample
            WHEN OLD.timelineItemId IS NOT NULL AND OLD.timelineItemId IS NOT NEW.timelineItemId
            BEGIN
                UPDATE TimelineItemBase
                SET startDate = (
                    SELECT MIN(date)
                    FROM LocomotionSample
                    WHERE timelineItemId = OLD.timelineItemId
                ),
                endDate = (
                    SELECT MAX(date)
                    FROM LocomotionSample
                    WHERE timelineItemId = OLD.timelineItemId
                ),
                samplesChanged = 1
                WHERE id = OLD.timelineItemId;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_AFTER_UPDATE_activityType_or_disabled", table: "LocomotionSample", family: .sampleDates, body: """
             AFTER UPDATE OF confirmedActivityType, classifiedActivityType, disabled ON LocomotionSample
             WHEN NEW.timelineItemId IS NOT NULL AND
                 (OLD.confirmedActivityType IS NOT NEW.confirmedActivityType OR
                 OLD.classifiedActivityType IS NOT NEW.classifiedActivityType OR
                 OLD.disabled != NEW.disabled)
             BEGIN
                 UPDATE TimelineItemBase
                 SET samplesChanged = 1
                 WHERE id = NEW.timelineItemId;
             END;
            """),
    ]

    // MARK: - Disabled state: item→sample cascade + sample-side guards

    /// The regime since `disabled_state_auto_sync`: the item side CASCADES (never aborts) and the
    /// sample side GUARDS. The old item-side check was dropped by that migration and is not in
    /// the registry. Consequence for writers: set the item's `disabled` and let the cascade
    /// flip its samples; flipping a sample's `disabled` while its parent still disagrees ABORTs.

    static let disabledSyncTriggers: [TriggerDefinition] = [
        TriggerDefinition(name: "TimelineItemBase_AFTER_UPDATE_disabled_sync", table: "TimelineItemBase", family: .disabledSync, body: """
            AFTER UPDATE OF disabled ON TimelineItemBase
            WHEN NEW.disabled != OLD.disabled
            BEGIN
                UPDATE LocomotionSample
                SET disabled = NEW.disabled
                WHERE timelineItemId = NEW.id;
            END;
            """),

        // prevent assigning samples with wrong disabled state
        TriggerDefinition(name: "LocomotionSample_BEFORE_INSERT_disabled_check", table: "LocomotionSample", family: .disabledSync, body: """
            BEFORE INSERT ON LocomotionSample
            BEGIN
                SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND disabled != NEW.disabled;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_BEFORE_UPDATE_disabled_check", table: "LocomotionSample", family: .disabledSync, body: """
            BEFORE UPDATE OF disabled, timelineItemId ON LocomotionSample
            BEGIN
                SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND disabled != NEW.disabled;
            END;
            """),
    ]

    // MARK: - Deleted item guards

    /// prevent assigning samples to deleted items (`sample_deleted_item_guard`)

    static let deletedGuardTriggers: [TriggerDefinition] = [
        TriggerDefinition(name: "LocomotionSample_BEFORE_INSERT_deleted_check", table: "LocomotionSample", family: .deletedGuards, body: """
            BEFORE INSERT ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL
            BEGIN
                SELECT RAISE(ABORT, 'Cannot assign sample to a deleted item')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND deleted = 1;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_BEFORE_UPDATE_deleted_check", table: "LocomotionSample", family: .deletedGuards, body: """
            BEFORE UPDATE OF timelineItemId ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL AND OLD.timelineItemId IS NOT NEW.timelineItemId
            BEGIN
                SELECT RAISE(ABORT, 'Cannot assign sample to a deleted item')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND deleted = 1;
            END;
            """),
    ]
}
