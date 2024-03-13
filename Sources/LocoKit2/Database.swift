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

    private var migrator = DatabaseMigrator()

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
            try db.create(table: "SampleBase") { table in
                table.column("id", .text).primaryKey()
                table.column("date", .datetime).notNull().indexed()
                table.column("source", .text).notNull().indexed()
                table.column("secondsFromGMT", .integer).notNull()
                table.column("movingState", .integer).notNull()
                table.column("recordingState", .integer).notNull()
                table.column("classifiedType", .text)
                table.column("confirmedType", .text)
            }

            try db.create(table: "SampleLocation") { table in
                table.column("sampleId", .text).primaryKey()
                    .references("SampleBase", onDelete: .cascade, onUpdate: .cascade, deferred: true)
                table.column("timestamp", .datetime).notNull() // hmm. duplicates base.date. not happy
                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("altitude", .double).notNull()
                table.column("horizontalAccuracy", .double).notNull()
                table.column("verticalAccuracy", .double).notNull()
                table.column("speed", .double).notNull()
                table.column("course", .double).notNull()
            }

            try db.create(table: "SampleExtended") { table in
                table.column("sampleId", .text).primaryKey()
                    .references("SampleBase", onDelete: .cascade, onUpdate: .cascade, deferred: true)
                table.column("stepHz", .double)
                table.column("courseVariance", .double)
                table.column("xyAcceleration", .double)
                table.column("zAcceleration", .double)
            }

            // TODO: if all LocomotionSampleExtended values are nil, delete the row?

            // TODO: r-tree index for SampleLocation
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
