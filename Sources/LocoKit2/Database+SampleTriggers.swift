//
//  Database+SampleTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addSampleTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial triggers") { db in

            // MARK: - AFTER INSERT LocomotionSample

            /** update startDate and endDate on sample insert */

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

            // MARK: - AFTER UPDATE LocomotionSample

            /** update startDate and endDate on sample assign */

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

            /** update startDate and endDate on sample unassign */

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

            // set samplesChanged if significant sample values change

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
    }
}
