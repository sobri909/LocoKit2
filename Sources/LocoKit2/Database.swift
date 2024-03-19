//
//  Database.swift
//  
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import GRDB

public class Database {

    public static let highlander = Database()

    // MARK: - Pool

    public static var pool: DatabasePool { return highlander.pool }

    public private(set) lazy var pool: DatabasePool = {
        return try! DatabasePool(path: appContainerDbUrl.path, configuration: config)
    }()

    private lazy var config: Configuration = {
        var config = Configuration()
        config.busyMode = .timeout(30)
        config.defaultTransactionKind = .immediate
        config.maximumReaderCount = 12
        return config
    }()

    // MARK: - Migrations

    private lazy var migrator = {
        var migrator = DatabaseMigrator()
        // TODO: remove this after schema is stable!
        migrator.eraseDatabaseOnSchemaChange = true
        return migrator
    }()

    public func doMigrations() {
        addMigrations()
        do {
            try migrator.migrate(pool)
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    public func doDelayedMigrations() async {
        do {
            try migrator.migrate(pool)
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    public var haveDelayedMigrationsToDo: Bool {
        do {
            let registered = migrator.migrations
            let done = try pool.read { try migrator.appliedMigrations($0) }
            let remaining = Set(registered).subtracting(Set(done))
            return !remaining.isEmpty

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
            return false
        }
    }

    public func eraseTheDb() {
        DebugLogger.logger.info("ERASING THE DATABASE", subsystem: .database)
        do {
            try Database.pool.erase()
            migrator = DatabaseMigrator()
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    // MARK: -

    private func addMigrations() {
        migrator.registerMigration("Initial") { db in

            // MARK: - Place

            try db.create(table: "Place") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).indexed()
            }

            // TODO: r-tree index for Place

            // MARK: - TimelineItem

            try db.create(table: "TimelineItemBase") { table in
                table.column("id", .text).primaryKey()
                table.column("isVisit", .boolean).notNull()
                table.column("startDate", .datetime).indexed()
                table.column("endDate", .datetime).indexed()
                table.column("source", .text).notNull()
                table.column("deleted", .boolean).notNull()

                table.column("previousItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check(sql: "previousItemId != id AND (previousItemId IS NULL OR deleted = 0)")

                table.column("nextItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check(sql: "nextItemId != id AND (nextItemId IS NULL OR deleted = 0)")

                table.column("stepCount", .integer)
                table.column("floorsAscended", .integer)
                table.column("floorsDescended", .integer)
                table.column("averageAltitude", .double)
                table.column("activeEnergyBurned", .double)
                table.column("averageHeartRate", .double)
                table.column("maxHeartRate", .double)
            }

            try db.create(table: "TimelineItemVisit") { table in
                table.column("itemId", .text).primaryKey()
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)

                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()
                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()

                table.column("placeId", .text).indexed()
                    .references("Place", onDelete: .setNull, deferred: true)

                table.column("confirmedPlace", .boolean).notNull()
            }

            try db.create(table: "TimelineItemTrip") { table in
                table.column("itemId", .text).primaryKey()
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)

                table.column("distance", .double).notNull()
                table.column("classifiedActivityType", .text)
                table.column("confirmedActivityType", .text)
            }

            // MARK: - LocomotionSample

            try db.create(table: "LocomotionSample") { table in
                table.column("id", .text).primaryKey()
                table.column("date", .datetime).notNull().indexed()
                table.column("source", .text).notNull()
                table.column("secondsFromGMT", .integer).notNull()
                table.column("movingState", .integer).notNull()
                table.column("recordingState", .integer).notNull()

                table.column("timelineItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)

                // CLLocation
                table.column("latitude", .double)
                table.column("longitude", .double)
                table.column("altitude", .double)
                table.column("horizontalAccuracy", .double)
                table.column("verticalAccuracy", .double)
                table.column("speed", .double)
                table.column("course", .double)
                
                table.column("classifiedActivityType", .text)
                table.column("confirmedActivityType", .text)

                // motion sensor data
                table.column("stepHz", .double)
                table.column("xyAcceleration", .double)
                table.column("zAcceleration", .double)
            }

            // TODO: r-tree index for LocomotionSample

            // MARK: - Triggers

            // update startDate and endDate on sample insert
            try db.execute(sql: """
                CREATE TRIGGER LocomotionSample_INSERT_TimelineItem_DateRangeOnAssign
                AFTER INSERT ON LocomotionSample
                WHEN NEW.timelineItemId IS NOT NULL
                BEGIN
                    UPDATE TimelineItemBase
                    SET startDate = (
                        SELECT MIN(date)
                        FROM LocomotionSample
                        WHERE timelineItemId = NEW.timelineItemId
                    ),
                    endDate = (
                        SELECT MAX(date)
                        FROM LocomotionSample
                        WHERE timelineItemId = NEW.timelineItemId
                    )
                    WHERE id = NEW.timelineItemId;
                END;
                """)

            // update startDate and endDate on sample assign
            try db.execute(sql: """
                CREATE TRIGGER LocomotionSample_UPDATE_TimelineItem_DateRangeOnAssign
                AFTER UPDATE OF timelineItemId ON LocomotionSample
                WHEN NEW.timelineItemId IS NOT NULL AND (OLD.timelineItemId IS NULL OR OLD.timelineItemId != NEW.timelineItemId)
                BEGIN
                    UPDATE TimelineItemBase
                    SET startDate = (
                        SELECT MIN(date)
                        FROM LocomotionSample
                        WHERE timelineItemId = NEW.timelineItemId
                    ),
                    endDate = (
                        SELECT MAX(date)
                        FROM LocomotionSample
                        WHERE timelineItemId = NEW.timelineItemId
                    )
                    WHERE id = NEW.timelineItemId;
                END;
                """)

            // update startDate and endDate on sample unassign
            try db.execute(sql: """
                CREATE TRIGGER LocomotionSample_UPDATE_TimelineItem_DateRangeOnUnassign
                AFTER UPDATE OF timelineItemId ON LocomotionSample
                WHEN OLD.timelineItemId IS NOT NULL AND (NEW.timelineItemId IS NULL OR OLD.timelineItemId != NEW.timelineItemId)
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
                    )
                    WHERE id = OLD.timelineItemId;
                END;
                """)
        }
    }

    public func addDelayedMigrations() {

    }

    // MARK: - URLs

    private lazy var appContainerDbDir: URL = {
        return try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }()

    private lazy var appContainerDbUrl: URL = {
        return appContainerDbDir.appendingPathComponent("LocoKit2.sqlite")
    }()

}
