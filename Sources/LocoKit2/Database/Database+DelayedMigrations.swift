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

            // create sample-side constraints: prevent assigning samples with wrong disabled state
            try? db.execute(sql: """
                CREATE TRIGGER LocomotionSample_BEFORE_INSERT_disabled_check
                BEFORE INSERT ON LocomotionSample
                BEGIN
                    SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                    FROM TimelineItemBase
                    WHERE id = NEW.timelineItemId
                    AND disabled != NEW.disabled;
                END;
                """)

            try? db.execute(sql: """
                CREATE TRIGGER LocomotionSample_BEFORE_UPDATE_disabled_check
                BEFORE UPDATE OF disabled, timelineItemId ON LocomotionSample
                BEGIN
                    SELECT RAISE(ABORT, 'Sample disabled state must match parent item disabled state')
                    FROM TimelineItemBase
                    WHERE id = NEW.timelineItemId
                    AND disabled != NEW.disabled;
                END;
                """)
        }

        migrator.registerMigration("sample_deleted_item_guard") { db in
            // prevent assigning samples to deleted items
            try? db.execute(sql: """
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

            try? db.execute(sql: """
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

        migrator.registerMigration("orphan_samples_from_deleted_items") { db in
            // BIG-367: One-time cleanup — orphan samples pointing to deleted items
            // so that BIG-115 orphan adoption can re-home them to active items
            let count = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM LocomotionSample
                WHERE timelineItemId IN (SELECT id FROM TimelineItemBase WHERE deleted = 1)
                """) ?? 0

            if count > 0 {
                Log.info("Orphaning \(count) samples from deleted items", subsystem: .database)
                try db.execute(sql: """
                    UPDATE LocomotionSample SET timelineItemId = NULL
                    WHERE timelineItemId IN (SELECT id FROM TimelineItemBase WHERE deleted = 1)
                    """)
            }
        }

        migrator.registerMigration("LocomotionSample.nullableSecondsFromGMT") { db in
            // BIG-341: Make secondsFromGMT nullable for pre-2019 samples
            Log.info("Starting LocomotionSample table rebuild (BIG-341)", subsystem: .database)
            let start = Date()

            try? db.create(table: "LocomotionSample_new") { table in
                Database.defineLocomotionSampleTable(table)
            }

            // explicit column names to prevent position-based mismatch (BIG-382)
            try? db.execute(sql: """
                INSERT INTO LocomotionSample_new
                (id, lastSaved, rtreeId, date, source, sourceVersion, secondsFromGMT,
                 movingState, recordingState, disabled, timelineItemId,
                 latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy,
                 speed, course, stepHz, xyAcceleration, zAcceleration,
                 heartRate, classifiedActivityType, confirmedActivityType)
                SELECT
                 id, lastSaved, rtreeId, date, source, sourceVersion, secondsFromGMT,
                 movingState, recordingState, disabled, timelineItemId,
                 latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy,
                 speed, course, stepHz, xyAcceleration, zAcceleration,
                 heartRate, classifiedActivityType, confirmedActivityType
                FROM LocomotionSample
                """)

            try? db.drop(table: "LocomotionSample")
            try? db.rename(table: "LocomotionSample_new", to: "LocomotionSample")

            // recreate composite index (rtreeId index name fixed by LocomotionSample_fix_rtreeId_index migration)
            try? db.create(
                index: "LocomotionSample_on_date_rtreeId_confirmedActivityType_xyAcceleration_zAcceleration_stepHz",
                on: "LocomotionSample",
                columns: ["date", "rtreeId", "confirmedActivityType", "xyAcceleration", "zAcceleration", "stepHz"]
            )

            // recreate all sample triggers (dropped with the old table)
            try Database.createSampleTriggers(db)
            try Database.createSampleRTreeTriggers(db)
            try Database.createSampleLastSavedTrigger(db)
            try Database.createSampleGuardTriggers(db)

            Log.info("LocomotionSample table rebuild completed in \(String(format: "%.1f", -start.timeIntervalSinceNow))s", subsystem: .database)
        }

        migrator.registerMigration("TimelineItemVisit.nullableCoordinates") { db in
            // recreate table with nullable coordinates and constraint
            try? db.create(table: "TimelineItemVisit_new") { table in
                Database.defineTimelineItemVisitTable(table)
            }

            // copy data, converting null island coordinates to NULL
            try? db.execute(sql: """
                INSERT INTO TimelineItemVisit_new
                SELECT
                    itemId,
                    lastSaved,
                    CASE WHEN latitude = 0 AND longitude = 0 THEN NULL ELSE latitude END,
                    CASE WHEN latitude = 0 AND longitude = 0 THEN NULL ELSE longitude END,
                    radiusMean,
                    radiusSD,
                    placeId,
                    confirmedPlace,
                    uncertainPlace,
                    customTitle,
                    streetAddress
                FROM TimelineItemVisit
                """)

            // drop old table and rename new
            try? db.drop(table: "TimelineItemVisit")
            try? db.rename(table: "TimelineItemVisit_new", to: "TimelineItemVisit")
        }

        migrator.registerMigration("LocomotionSample_lastSaved_index") { db in
            // index for efficient incremental backup queries
            try? db.create(
                index: "LocomotionSample_on_lastSaved",
                on: "LocomotionSample",
                columns: ["lastSaved"]
            )
        }

        migrator.registerMigration("ImportState") { db in
            // singleton table for tracking partial import state
            // presence of row = partial import in progress, blocks other modifications
            try? db.create(table: "ImportState") { table in
                table.primaryKey("id", .integer)
                    .check { $0 == 1 }  // singleton
                table.column("exportId", .text)
                table.column("startedAt", .datetime).notNull()
                table.column("phase", .text).notNull()
                table.column("processedSampleFiles", .text)  // JSON array
                table.column("localCopyPath", .text)
            }
        }

        migrator.registerMigration("OldLocoKitImportState") { db in
            // singleton table for tracking old LocoKit import state (for resume on interruption)
            try? db.create(table: "OldLocoKitImportState") { table in
                table.primaryKey("id", .integer)
                    .check { $0 == 1 }  // singleton
                table.column("startedAt", .datetime).notNull()
                table.column("phase", .text).notNull()
                table.column("lastProcessedSampleRowId", .integer)
            }
        }
        
        // BIG-379: table rebuild leaves indexes with _new_ prefix (SQLite doesn't rename them)
        migrator.registerMigration("LocomotionSample_fix_rtreeId_index") { db in
            // drop stale _new_ prefixed index left by table rebuild rename
            try? db.execute(sql: "DROP INDEX IF EXISTS LocomotionSample_new_on_rtreeId")
            try? db.create(
                index: "LocomotionSample_on_rtreeId",
                on: "LocomotionSample",
                columns: ["rtreeId"]
            )
        }

        // BIG-306: Drift profile learning for Trust Factor
        migrator.registerMigration("DriftProfile") { db in
            try? db.create(table: "DriftProfile") { table in
                Database.defineDriftProfileTable(table)
            }

            try? db.execute(sql: """
                CREATE TRIGGER DriftProfile_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON DriftProfile
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE DriftProfile SET lastSaved = CURRENT_TIMESTAMP WHERE id = NEW.id;
                END;
                """)
        }

        migrator.registerMigration("Place.foursquareCategoryV2Id") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "foursquareCategoryV2Id", .text)
            }
        }
    }
}
