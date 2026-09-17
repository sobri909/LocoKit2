//
//  Database+RTreeTriggers.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 7/4/25.
//

import GRDB

extension Database {
    func addRTreeTriggers(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial RTree triggers") { db in
            try Database.createTriggers(family: .rtree, in: db)
        }
    }

    static let rtreeTriggers: [TriggerDefinition] = [

        // MARK: - Place RTree Triggers

        /** maintain PlaceRTree when Place coordinates change */

        TriggerDefinition(name: "Place_AFTER_INSERT", table: "Place", family: .rtree, body: """
            AFTER INSERT ON Place
            BEGIN
                INSERT INTO PlaceRTree (latMin, latMax, lonMin, lonMax)
                VALUES (NEW.latitude, NEW.latitude, NEW.longitude, NEW.longitude);

                UPDATE Place
                SET rtreeId = last_insert_rowid()
                WHERE id = NEW.id;
            END;
            """),

        TriggerDefinition(name: "Place_AFTER_UPDATE_coordinates", table: "Place", family: .rtree, body: """
            AFTER UPDATE OF latitude, longitude ON Place
            WHEN OLD.latitude != NEW.latitude OR OLD.longitude != NEW.longitude OR NEW.rtreeId IS NULL
            BEGIN
                UPDATE PlaceRTree
                SET latMin = NEW.latitude, latMax = NEW.latitude,
                    lonMin = NEW.longitude, lonMax = NEW.longitude
                WHERE id = NEW.rtreeId;

                INSERT INTO PlaceRTree (latMin, latMax, lonMin, lonMax)
                SELECT NEW.latitude, NEW.latitude, NEW.longitude, NEW.longitude
                WHERE NEW.rtreeId IS NULL;

                UPDATE Place
                SET rtreeId = last_insert_rowid()
                WHERE id = NEW.id AND NEW.rtreeId IS NULL;
            END;
            """),

        TriggerDefinition(name: "Place_AFTER_DELETE", table: "Place", family: .rtree, body: """
            AFTER DELETE ON Place
            WHEN OLD.rtreeId IS NOT NULL
            BEGIN
                DELETE FROM PlaceRTree
                WHERE id = OLD.rtreeId;
            END;
            """),

        // MARK: - Sample RTree Triggers

        TriggerDefinition(name: "LocomotionSample_AFTER_INSERT_coordinates", table: "LocomotionSample", family: .rtree, body: """
            AFTER INSERT ON LocomotionSample
            WHEN NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL
            BEGIN
                INSERT INTO SampleRTree (latMin, latMax, lonMin, lonMax)
                VALUES (NEW.latitude, NEW.latitude, NEW.longitude, NEW.longitude);

                UPDATE LocomotionSample
                SET rtreeId = last_insert_rowid()
                WHERE id = NEW.id;
            END;
            """),

        TriggerDefinition(name: "LocomotionSample_AFTER_DELETE_rtreeId", table: "LocomotionSample", family: .rtree, body: """
            AFTER DELETE ON LocomotionSample
            WHEN OLD.rtreeId IS NOT NULL
            BEGIN
                DELETE FROM SampleRTree
                WHERE id = OLD.rtreeId;
            END;
            """),
    ]
}
