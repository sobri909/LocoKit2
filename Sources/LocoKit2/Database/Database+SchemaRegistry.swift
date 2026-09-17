//
//  Database+SchemaRegistry.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-17
//

import Foundation
import GRDB

/// One SQL trigger, defined exactly once. The registry below is the single source of truth for
/// every trigger the database is meant to carry; migrations, table rebuilds and the schema audit
/// all read from it, so a trigger's SQL cannot drift between the places that create it.
///
/// BIG-748: the `TimelineItemVisit.nullableCoordinates` rebuild dropped the visit table and, with
/// it, `TimelineItemVisit_AFTER_UPDATE_lastSaved_UNCHANGED` — on every install, fresh ones
/// included — because that trigger's SQL lived inline in a one-shot migration and the rebuild had
/// nothing to call. Nothing noticed for three months. This file exists so that cannot recur:
/// `rebuildTable` recreates a table's triggers from here, and `auditSchema` reports any gap.
///
/// Editing a definition here changes what fresh installs get from day one AND what the next
/// `ensureSchema` repair installs. Existing installs only change via a migration that drops and
/// recreates the trigger (see `disabled_state_auto_sync` for the shape).
public struct TriggerDefinition: Sendable {
    public let name: String
    public let table: String
    public let family: TriggerFamily
    /// Everything after `CREATE TRIGGER <name>`: the event clause, WHEN, and BEGIN…END.
    public let body: String

    public init(name: String, table: String, family: TriggerFamily, body: String) {
        self.name = name
        self.table = table
        self.family = family
        self.body = body
    }

    var createSQL: String { "CREATE TRIGGER IF NOT EXISTS \(name)\n\(body)" }
}

/// Which migration originally introduced a group of triggers. Migrations create by family;
/// table rebuilds create by table. Both read the same list.
public enum TriggerFamily: Sendable {
    case lastSaved
    case edges
    case sampleDates
    case rtree
    /// The item→sample disabled cascade plus the sample-side disabled guards
    /// (`disabled_state_auto_sync`, which also DROPPED the item-side check).
    case disabledSync
    /// The sample-side "no assigning to a deleted item" guards (`sample_deleted_item_guard`).
    case deletedGuards
    /// Triggers owned by the host app (registered via `Database.registerAppTriggers`).
    case app
}

/// An explicitly created index (`db.create(index:on:columns:)`), as opposed to the
/// single-column ones GRDB derives from `.indexed()` in a table definition. Those derived
/// indexes are named `<Table>_on_<column>` by GRDB and are recreated with the table; the
/// explicit ones are dropped with the table and must be recreated from here.
public struct IndexDefinition: Sendable {
    public let name: String
    public let table: String
    public let columns: [String]
    public let unique: Bool

    public init(name: String, table: String, columns: [String], unique: Bool = false) {
        self.name = name
        self.table = table
        self.columns = columns
        self.unique = unique
    }
}

/// What `auditSchema` found. Empty lists mean the live schema matches the registry.
public struct SchemaAudit: Sendable {
    public let missingTriggers: [String]
    public let missingIndexes: [String]
    /// Indexes still carrying a `<Table>_new_` prefix from a table rebuild's rename.
    public let strayIndexes: [String]

    public var isClean: Bool { missingTriggers.isEmpty && missingIndexes.isEmpty && strayIndexes.isEmpty }

    public var summary: String {
        if isClean { return "schema audit: clean" }
        var parts: [String] = []
        if !missingTriggers.isEmpty { parts.append("missing triggers: \(missingTriggers.joined(separator: ", "))") }
        if !missingIndexes.isEmpty { parts.append("missing indexes: \(missingIndexes.joined(separator: ", "))") }
        if !strayIndexes.isEmpty { parts.append("stray _new_ indexes: \(strayIndexes.joined(separator: ", "))") }
        return "schema audit: " + parts.joined(separator: "; ")
    }
}

extension Database {

    // MARK: - The registry

    /// Every trigger LocoKit2's schema carries, by family. Each family's definitions live in the
    /// file named for it (`Database+LastSavedTriggers.swift` etc.); this is the aggregate.
    static let triggerDefinitions: [TriggerDefinition] =
        lastSavedTriggers + edgeTriggers + sampleDateTriggers + rtreeTriggers
        + disabledSyncTriggers + deletedGuardTriggers

    /// Every explicitly created index LocoKit2's schema carries.
    static let indexDefinitions: [IndexDefinition] = [
        IndexDefinition(name: "TimelineItemBase_on_deleted_startDate",
                        table: "TimelineItemBase", columns: ["deleted", "startDate"]),
        IndexDefinition(name: "TimelineItemBase_on_deleted_disabled_endDate",
                        table: "TimelineItemBase", columns: ["deleted", "disabled", "endDate"]),
        IndexDefinition(name: "TimelineItemBase_on_isVisit_deleted_disabled_startDate",
                        table: "TimelineItemBase", columns: ["isVisit", "deleted", "disabled", "startDate"]),
        IndexDefinition(name: "LocomotionSample_on_date_rtreeId_confirmedActivityType_xyAcceleration_zAcceleration_stepHz",
                        table: "LocomotionSample",
                        columns: ["date", "rtreeId", "confirmedActivityType", "xyAcceleration", "zAcceleration", "stepHz"]),
    ]

    /// Triggers and indexes the host app owns (e.g. Arc's Note triggers, one of which sits ON
    /// TimelineItemBase and would be dropped by a LocoKit2 rebuild of that table). The app
    /// registers them once at launch, before migrations run. Single-assignment by convention;
    /// `nonisolated(unsafe)` because it is written once on the main thread during App.init and
    /// only read afterwards.
    nonisolated(unsafe) static var appTriggerDefinitions: [TriggerDefinition] = []
    nonisolated(unsafe) static var appIndexDefinitions: [IndexDefinition] = []

    public static func registerAppTriggers(_ triggers: [TriggerDefinition], indexes: [IndexDefinition] = []) {
        appTriggerDefinitions += triggers
        appIndexDefinitions += indexes
    }

    static var allTriggerDefinitions: [TriggerDefinition] { triggerDefinitions + appTriggerDefinitions }
    static var allIndexDefinitions: [IndexDefinition] { indexDefinitions + appIndexDefinitions }

    // MARK: - Creating from the registry

    /// Create every registry trigger of one family. Used by the migrations that introduced them.
    static func createTriggers(family: TriggerFamily, in db: GRDB.Database) throws {
        for trigger in allTriggerDefinitions where trigger.family == family {
            try db.execute(sql: trigger.createSQL)
        }
    }

    /// Create every registry trigger ON one table (LocoKit2's and the app's). Used after a table
    /// rebuild, which drops them all.
    static func createTriggers(on table: String, in db: GRDB.Database) throws {
        for trigger in allTriggerDefinitions where trigger.table == table {
            try db.execute(sql: trigger.createSQL)
        }
    }

    public static func createTrigger(named name: String, in db: GRDB.Database) throws {
        guard let trigger = allTriggerDefinitions.first(where: { $0.name == name }) else {
            throw DatabaseError(message: "No registered trigger named \(name)")
        }
        try db.execute(sql: trigger.createSQL)
    }

    /// Create every explicitly registered index ON one table. Used after a table rebuild.
    static func createIndexes(on table: String, in db: GRDB.Database) throws {
        for index in allIndexDefinitions where index.table == table {
            try db.create(index: index.name, on: index.table, columns: index.columns,
                          options: index.unique ? [.ifNotExists, .unique] : [.ifNotExists])
        }
    }

    // MARK: - Table rebuilds

    /// The one way to rebuild a table for a change ALTER can't make. Creates `<table>_new` from
    /// `define`, runs the caller's copy statement, drops the old table, renames, then repairs
    /// what SQLite silently loses in that sequence: the derived `.indexed()` indexes keep a
    /// `<table>_new_` prefix after the rename (BIG-379), and every trigger and explicit index on
    /// the table is gone with it (BIG-748). Both are put back from the registry.
    ///
    /// `copySQL` receives the temporary table's name and must return the full
    /// `INSERT INTO <new> (…) SELECT … FROM <table>` statement, with explicit column lists
    /// (BIG-382: `INSERT INTO … SELECT *` maps by ordinal position).
    public static func rebuildTable(
        _ table: String,
        in db: GRDB.Database,
        define: (TableDefinition) -> Void,
        copySQL: (_ newTable: String) -> String
    ) throws {
        let newTable = "\(table)_new"
        // a previous attempt that threw mid-way (a bad copy statement) leaves `_new` behind
        try db.execute(sql: "DROP TABLE IF EXISTS \"\(newTable)\"")
        try db.create(table: newTable, body: define)
        try db.execute(sql: copySQL(newTable))
        try db.drop(table: table)
        try db.rename(table: newTable, to: table)
        // the caller's migration must let a throw propagate so GRDB rolls the transaction back;
        // this check is what makes a silently half-done rebuild impossible to commit
        guard try db.tableExists(table), try !db.tableExists(newTable) else {
            throw DatabaseError(message: "rebuildTable(\(table)): rename did not land")
        }
        try renameStrayIndexes(on: table, in: db)
        try createIndexes(on: table, in: db)
        try createTriggers(on: table, in: db)
    }

    /// SQLite has no ALTER INDEX RENAME: a derived index created as `<table>_new_on_x` keeps that
    /// name after the table is renamed. Drop each such index and recreate it under `<table>_on_x`
    /// with the same columns (read from `PRAGMA index_info`, so no list of columns is needed here).
    /// Partial indexes are left alone: `index_info` cannot report their WHERE predicate, and none
    /// exist in this schema today.
    static func renameStrayIndexes(on table: String, in db: GRDB.Database) throws {
        let strayPrefix = "\(table)_new_"
        let indexes = try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(table)\")")
        for row in indexes {
            let name: String = row["name"]
            let origin: String = row["origin"]
            guard origin == "c", name.hasPrefix(strayPrefix) else { continue }
            if (row["partial"] as Int64? ?? 0) == 1 {
                Log.error("renameStrayIndexes: skipping partial index \(name) (predicate not recoverable)", subsystem: .database)
                continue
            }
            let unique: Bool = (row["unique"] as Int64? ?? 0) == 1
            let columns: [String] = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(name)\")")
                .compactMap { $0["name"] as String? }
            guard !columns.isEmpty else { continue }
            let fixedName = "\(table)_" + name.dropFirst(strayPrefix.count)
            try db.execute(sql: "DROP INDEX IF EXISTS \"\(name)\"")
            try db.create(index: fixedName, on: table, columns: columns,
                          options: unique ? [.ifNotExists, .unique] : [.ifNotExists])
        }
    }

    // MARK: - Audit and repair

    /// Compare the live schema against the registry. Only tables that exist are checked, so a
    /// registered app trigger on a table the app hasn't created yet is not a false positive.
    public static func auditSchema(in db: GRDB.Database) throws -> SchemaAudit {
        let tables = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'"))
        let liveTriggers = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'"))
        let liveIndexes = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'")

        let missingTriggers = allTriggerDefinitions
            .filter { tables.contains($0.table) && !liveTriggers.contains($0.name) }
            .map(\.name)
        let missingIndexes = allIndexDefinitions
            .filter { tables.contains($0.table) && !liveIndexes.contains($0.name) }
            .map(\.name)
        let strayIndexes = liveIndexes.filter { name in
            tables.contains { name.hasPrefix("\($0)_new_") }
        }
        return SchemaAudit(missingTriggers: missingTriggers.sorted(),
                           missingIndexes: missingIndexes.sorted(),
                           strayIndexes: strayIndexes.sorted())
    }

    /// Put the schema back to what the registry says, for every table that exists: rename stray
    /// `_new_` indexes, recreate any missing explicit index and trigger (the app's included, when
    /// their tables exist — on a fresh install the app's tables arrive after this runs, so its own
    /// migrations create them there). Idempotent, and every step is IF NOT EXISTS.
    ///
    /// Each step is individually tolerant: this runs inside a migration that sits upstream of
    /// every app migration, and one transient failure (SQLITE_BUSY, a full disk) must not block
    /// those forever. What a step could not do, the audit that follows reports.
    static func ensureSchema(in db: GRDB.Database) throws {
        let tables = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'"))
        for table in tables {
            do { try renameStrayIndexes(on: table, in: db) }
            catch { Log.error("ensureSchema: stray index rename on \(table) failed: \(error)", subsystem: .database) }
        }
        for index in allIndexDefinitions where tables.contains(index.table) {
            do {
                try db.create(index: index.name, on: index.table, columns: index.columns,
                              options: index.unique ? [.ifNotExists, .unique] : [.ifNotExists])
            } catch { Log.error("ensureSchema: index \(index.name) failed: \(error)", subsystem: .database) }
        }
        for trigger in allTriggerDefinitions where tables.contains(trigger.table) {
            do { try db.execute(sql: trigger.createSQL) }
            catch { Log.error("ensureSchema: trigger \(trigger.name) failed: \(error)", subsystem: .database) }
        }
    }
}
