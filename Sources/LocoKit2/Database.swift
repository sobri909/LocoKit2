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

    public lazy var migrator = {
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
