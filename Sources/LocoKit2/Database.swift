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

//        config.prepareDatabase { db in
//            db.trace { event in
//                print("SQL: \(event.expandedDescription)")
//            }
//        }

        return config
    }()

    // MARK: - Migrations

    private lazy var migrator = {
        var migrator = DatabaseMigrator()
        // migrator.eraseDatabaseOnSchemaChange = true
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
        addInitialSchema(to: &migrator)
        addLastSavedTriggers(to: &migrator)
        addEdgeTriggers(to: &migrator)
        addSampleTriggers(to: &migrator)
    }

    public func addDelayedMigrations() {
        migrator.registerMigration("Add lastSaved columns and triggers") { db in
            // Add lastSaved columns
            try? db.alter(table: "Place") { table in
                table.add(column: "lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try? db.alter(table: "TimelineItemBase") { table in
                table.add(column: "lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try? db.alter(table: "TimelineItemVisit") { table in
                table.add(column: "lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try? db.alter(table: "TimelineItemTrip") { table in
                table.add(column: "lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try? db.alter(table: "LocomotionSample") { table in
                table.add(column: "lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            // Add timestamp update triggers
            try? db.execute(sql: """
                CREATE TRIGGER Place_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON Place
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE Place SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try? db.execute(sql: """
                CREATE TRIGGER TimelineItemBase_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON TimelineItemBase
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE TimelineItemBase SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try? db.execute(sql: """
                CREATE TRIGGER LocomotionSample_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON LocomotionSample
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE LocomotionSample SET lastSaved = CURRENT_TIMESTAMP
                    WHERE id = NEW.id;
                END;
                """)

            try? db.execute(sql: """
                CREATE TRIGGER TimelineItemVisit_AFTER_UPDATE_lastSaved_UNCHANGED
                AFTER UPDATE ON TimelineItemVisit
                WHEN NEW.lastSaved IS OLD.lastSaved
                BEGIN
                    UPDATE TimelineItemVisit SET lastSaved = CURRENT_TIMESTAMP
                    WHERE itemId = NEW.itemId;
                END;
                """)

            try? db.execute(sql: """
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
