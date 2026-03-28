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
            try Database.createSampleTriggers(db)
        }
    }

    static func createSampleTriggers(_ db: GRDB.Database) throws {
        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_AFTER_INSERT_timelineItemId_SET
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
            """)

        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_AFTER_UPDATE_timelineItemId_SET
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
            """)

        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_AFTER_UPDATE_timelineItemId_UNSET
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
            """)

        try db.execute(sql: """
             CREATE TRIGGER LocomotionSample_AFTER_UPDATE_activityType_or_disabled
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
            """)
    }

    static func createSampleGuardTriggers(_ db: GRDB.Database) throws {
        // prevent assigning samples with wrong disabled state
        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_BEFORE_INSERT_disabled_check
            BEFORE INSERT ON LocomotionSample
            BEGIN
                SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND disabled != NEW.disabled;
            END;
            """)

        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_BEFORE_UPDATE_disabled_check
            BEFORE UPDATE OF disabled, timelineItemId ON LocomotionSample
            BEGIN
                SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND disabled != NEW.disabled;
            END;
            """)

        // prevent assigning samples to deleted items
        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_BEFORE_INSERT_deleted_check
            BEFORE INSERT ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL
            BEGIN
                SELECT RAISE(ABORT, 'Cannot assign sample to a deleted item')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND deleted = 1;
            END;
            """)

        try db.execute(sql: """
            CREATE TRIGGER LocomotionSample_BEFORE_UPDATE_deleted_check
            BEFORE UPDATE OF timelineItemId ON LocomotionSample
            WHEN NEW.timelineItemId IS NOT NULL AND OLD.timelineItemId IS NOT NEW.timelineItemId
            BEGIN
                SELECT RAISE(ABORT, 'Cannot assign sample to a deleted item')
                FROM TimelineItemBase
                WHERE id = NEW.timelineItemId
                AND deleted = 1;
            END;
            """)
    }
}
