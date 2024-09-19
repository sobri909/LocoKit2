//
//  Database.swift
//  
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import GRDB

public final class Database: @unchecked Sendable {

    public static let highlander = Database()

    public var appGroup: AppGroup? 

    // MARK: - Pool

    public static var pool: DatabasePool { return highlander.pool }
    
    public static var legacyPool: DatabasePool? { return highlander.legacyPool }

    public private(set) lazy var pool: DatabasePool = {
        let dbUrl = appGroupDbUrl ?? appContainerDbUrl
        return try! DatabasePool(path: dbUrl.path, configuration: config)
    }()

    public private(set) lazy var legacyPool: DatabasePool? = {
        guard let dbUrl = appGroupLegacyDbUrl else { return nil }
        return try! DatabasePool(path: dbUrl.path, configuration: config)
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
            logger.error(error, subsystem: .database)
        }
    }

    public func doDelayedMigrations() async {
        do {
            try migrator.migrate(pool)
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public var haveDelayedMigrationsToDo: Bool {
        do {
            let registered = migrator.migrations
            let done = try pool.read { try migrator.appliedMigrations($0) }
            let remaining = Set(registered).subtracting(Set(done))
            return !remaining.isEmpty

        } catch {
            logger.error(error, subsystem: .database)
            return false
        }
    }

    public func eraseTheDb() {
        logger.info("ERASING THE DATABASE", subsystem: .database)
        do {
            try Database.pool.erase()
            migrator = DatabaseMigrator()
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: -

    private func addMigrations() {
        migrator.registerMigration("Initial") { db in

            // MARK: - Place

            try db.create(table: "Place") { table in
                table.primaryKey("id", .text)
                table.column("rtreeId", .integer).indexed()
                table.column("isStale", .boolean).notNull()
                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()
            }

            try db.create(
                virtualTable: "PlaceRTree",
                using: "rtree(id, latMin, latMax, lonMin, lonMax)"
            )

            // MARK: - TimelineItem

            try db.create(table: "TimelineItemBase") { table in
                table.primaryKey("id", .text)
                table.column("isVisit", .boolean).notNull()
                table.column("startDate", .datetime).indexed()
                table.column("endDate", .datetime).indexed()
                table.column("source", .text).notNull()
                table.column("sourceVersion", .text).notNull()
                table.column("disabled", .boolean).notNull()
                table.column("deleted", .boolean).notNull()
                table.column("samplesChanged", .boolean).notNull()

                table.column("previousItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check { $0 == nil || Column("deleted") == false }
                    .check { $0 != Column("id") }

                table.column("nextItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check { $0 == nil || Column("deleted") == false }
                    .check { $0 != Column("id") }

                table.column("stepCount", .integer)
                table.column("floorsAscended", .integer)
                table.column("floorsDescended", .integer)
                table.column("averageAltitude", .double)
                table.column("activeEnergyBurned", .double)
                table.column("averageHeartRate", .double)
                table.column("maxHeartRate", .double)
            }

            try db.create(table: "TimelineItemVisit") { table in
                table.primaryKey("itemId", .text)
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)

                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()

                table.column("placeId", .text).indexed()
                    .references("Place", onDelete: .setNull, deferred: true)

                table.column("confirmedPlace", .boolean).notNull()
            }

            try db.create(table: "TimelineItemTrip") { table in
                table.primaryKey("itemId", .text)
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)

                table.column("distance", .double).notNull()
                table.column("speed", .double).notNull()
                table.column("classifiedActivityType", .text)
                table.column("confirmedActivityType", .text)
            }

            // MARK: - LocomotionSample

            try db.create(table: "LocomotionSample") { table in
                table.primaryKey("id", .text)

                // NOTE: indexing this column in old LocoKit made the query planner do dumb things
                // make sure there's a composite index that includes it instead
                // and make sure rtreeId IS NOT the first column in the composite index
                // otherwise again the query planner will do dumb things
                table.column("rtreeId", .integer)

                table.column("date", .datetime).notNull().indexed()
                table.column("source", .text).notNull()
                table.column("sourceVersion", .text).notNull()
                table.column("secondsFromGMT", .integer).notNull()
                table.column("movingState", .integer).notNull()
                table.column("recordingState", .integer).notNull()
                table.column("disabled", .boolean).notNull()

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

                // motion sensor data
                table.column("stepHz", .double)
                table.column("xyAcceleration", .double)
                table.column("zAcceleration", .double)
                
                table.column("classifiedActivityType", .text)
                table.column("confirmedActivityType", .text)
            }

            try db.create(
                virtualTable: "SampleRTree",
                using: "rtree(id, latMin, latMax, lonMin, lonMax)"
            )

            try db.create(
                index: "LocomotionSample_on_date_rtreeId_confirmedActivityType_xyAcceleration_zAcceleration_stepHz",
                on: "LocomotionSample",
                columns: ["date", "rtreeId", "confirmedActivityType", "xyAcceleration", "zAcceleration", "stepHz"]
            )

            // MARK: - ActivityTypesModel

            try db.create(table: "ActivityTypesModel") { table in
                table.column("geoKey", .text).primaryKey()
                table.column("lastSaved", .datetime).notNull().indexed()
                table.column("lastUpdated", .datetime).indexed()
                table.column("filename", .text).notNull()

                table.column("depth", .integer).notNull().indexed()
                table.column("needsUpdate", .boolean).indexed()
                table.column("totalSamples", .integer).notNull()
                table.column("accuracyScore", .double)

                table.column("latitudeMax", .double).notNull().indexed()
                table.column("latitudeMin", .double).notNull().indexed()
                table.column("longitudeMax", .double).notNull().indexed()
                table.column("longitudeMin", .double).notNull().indexed()
            }

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
                    ),
                    samplesChanged = 1
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
                    ),
                    samplesChanged = 1
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
                    ),
                    samplesChanged = 1
                    WHERE id = OLD.timelineItemId;
                END;
                """)

            // keep nextItemId / previousItemId links correct
            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_UPDATE_nextItemId
                AFTER UPDATE OF previousItemId ON TimelineItemBase
                BEGIN
                    UPDATE TimelineItemBase
                    SET nextItemId = NEW.id
                    WHERE id = NEW.previousItemId;
                    
                    UPDATE TimelineItemBase
                    SET nextItemId = NULL
                    WHERE nextItemId = NEW.id AND id != NEW.previousItemId;
                END;
                """)

            // keep nextItemId / previousItemId links correct
            try db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_UPDATE_previousItemId
                AFTER UPDATE OF nextItemId ON TimelineItemBase
                BEGIN
                    UPDATE TimelineItemBase
                    SET previousItemId = NEW.id
                    WHERE id = NEW.nextItemId;
                    
                    UPDATE TimelineItemBase
                    SET previousItemId = NULL
                    WHERE previousItemId = NEW.id AND id != NEW.nextItemId;
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

    var appGroupDbDir: URL? {
        guard let suiteName = appGroup?.suiteName else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    // MARK: -

    private lazy var appContainerDbUrl: URL = {
        return appContainerDbDir.appendingPathComponent("LocoKit2.sqlite")
    }()

    private var appGroupDbUrl: URL? {
        return appGroupDbDir?.appendingPathComponent("LocoKit2.sqlite")
    }

    private var appGroupLegacyDbUrl: URL? {
        return appGroupDbDir?.appendingPathComponent("LocoKit.sqlite")
    }

}
