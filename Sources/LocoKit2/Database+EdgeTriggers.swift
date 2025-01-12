//
//  Database+EdgeTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addEdgeTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial edge triggers") { db in

            // MARK: - BEFORE INSERT TimelineItemBase

            /** prevent setting previousItemId or nextItemId to a deleted item */

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_INSERT_previousItemId_SET
                BEFORE INSERT ON TimelineItemBase
                WHEN NEW.previousItemId IS NOT NULL
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot set previousItemId to a deleted item')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase WHERE id = NEW.previousItemId AND deleted = 1
                    );
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_INSERT_nextItemId_SET
                BEFORE INSERT ON TimelineItemBase
                WHEN NEW.nextItemId IS NOT NULL
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot set nextItemId to a deleted item')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase WHERE id = NEW.nextItemId AND deleted = 1
                    );
                END;
                """)

            // MARK: - BEFORE UPDATE TimelineItemBase

            /** prevent setting previousItemId or nextItemId to a deleted item */

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_UPDATE_previousItemId_SET
                BEFORE UPDATE OF previousItemId ON TimelineItemBase
                WHEN NEW.previousItemId IS NOT NULL AND OLD.previousItemId IS NOT NEW.previousItemId
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot set previousItemId to a deleted item')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase WHERE id = NEW.previousItemId AND deleted = 1
                    );
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_UPDATE_nextItemId_SET
                BEFORE UPDATE OF nextItemId ON TimelineItemBase
                WHEN NEW.nextItemId IS NOT NULL AND OLD.nextItemId IS NOT NEW.nextItemId
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot set nextItemId to a deleted item')
                    WHERE EXISTS (
                        SELECT 1 FROM TimelineItemBase WHERE id = NEW.nextItemId AND deleted = 1
                    );
                END;
                """)

            // prevent deletion of items that still have samples

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_BEFORE_UPDATE_deleted_SET
                BEFORE UPDATE OF deleted ON TimelineItemBase
                WHEN NEW.deleted = 1 AND OLD.deleted = 0
                BEGIN
                    SELECT RAISE(ABORT, 'Cannot delete TimelineItem with existing samples')
                    WHERE EXISTS (
                        SELECT 1 FROM LocomotionSample WHERE timelineItemId = OLD.id
                    );
                END;
                """)

            // MARK: - AFTER INSERT TimelineItemBase

            /** keep nextItemId and previousItemId links correct */

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_INSERT_previousItemId_SET
                AFTER INSERT ON TimelineItemBase
                WHEN NEW.previousItemId IS NOT NULL
                BEGIN
                    UPDATE TimelineItemBase
                    SET nextItemId = NEW.id
                    WHERE id = NEW.previousItemId;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_INSERT_nextItemId_SET
                AFTER INSERT ON TimelineItemBase
                WHEN NEW.nextItemId IS NOT NULL
                BEGIN
                    UPDATE TimelineItemBase
                    SET previousItemId = NEW.id
                    WHERE id = NEW.nextItemId;
                END;
                """)

            // MARK: - AFTER UPDATE TimelineItemBase

            /** keep nextItemId and previousItemId links correct */

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_previousItemId
                AFTER UPDATE OF previousItemId ON TimelineItemBase
                BEGIN
                    UPDATE TimelineItemBase
                    SET nextItemId = NEW.id
                    WHERE id = NEW.previousItemId;
                    
                    UPDATE TimelineItemBase
                    SET nextItemId = NULL
                    WHERE nextItemId = NEW.id AND id IS NOT NEW.previousItemId;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_nextItemId
                AFTER UPDATE OF nextItemId ON TimelineItemBase
                BEGIN
                    UPDATE TimelineItemBase
                    SET previousItemId = NEW.id
                    WHERE id = NEW.nextItemId;
                    
                    UPDATE TimelineItemBase
                    SET previousItemId = NULL
                    WHERE previousItemId = NEW.id AND id IS NOT NEW.nextItemId;
                END;
                """)

            /** break edges on item delete and disable */

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_deleted
                AFTER UPDATE OF deleted ON TimelineItemBase
                WHEN NEW.deleted = 1 AND OLD.deleted = 0
                BEGIN
                    UPDATE TimelineItemBase SET nextItemId = NULL, previousItemId = NULL WHERE id = NEW.id;
                END;
                """)

            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_disabled
                AFTER UPDATE OF disabled ON TimelineItemBase
                WHEN NEW.disabled = 1 AND OLD.disabled = 0
                BEGIN
                    UPDATE TimelineItemBase SET nextItemId = NULL, previousItemId = NULL WHERE id = NEW.id;
                END;
                """)
        }
    }
}
