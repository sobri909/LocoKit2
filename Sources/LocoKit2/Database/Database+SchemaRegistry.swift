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
/// launch-time schema repair installs. Existing installs only change via a migration that drops and
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
        try replaceStrayIndexes(on: table, in: db)
        try createMissingDerivedIndexes(on: table, in: db, define: define)
        try createIndexes(on: table, in: db)
        try createTriggers(on: table, in: db)
    }

    // MARK: - Derived indexes

    /// A single-column index GRDB derives from `.indexed()` in a table definition, named
    /// `<Table>_on_<column>`. Not listed anywhere by hand: read off the table's own definition
    /// (see `expectedDerivedIndexes`), so the schema stays defined exactly once.
    struct DerivedIndex: Sendable {
        let name: String
        let columns: [String]
        let unique: Bool
    }

    /// The tables `rebuildTable` can rebuild, each with the definition it builds from. These are
    /// the only tables whose derived indexes can ever go missing: a derived index is created with
    /// its table and lost only by a rebuild (BIG-379, BIG-792). Everything else keeps the indexes
    /// its initial `db.create(table:)` gave it.
    static func rebuildableDefinition(for table: String) -> ((TableDefinition) -> Void)? {
        switch table {
        case "TimelineItemVisit": return defineTimelineItemVisitTable
        case "LocomotionSample": return defineLocomotionSampleTable
        case "DailyRecordingStats": return defineDailyRecordingStatsTable
        case "DriftProfile": return defineDriftProfileTable
        default: return nil
        }
    }

    /// The derived indexes a rebuildable table is meant to carry, read from its definition: the
    /// table is created in a throwaway in-memory database and its index list read back. Empty
    /// for tables that cannot be rebuilt.
    static func expectedDerivedIndexes(on table: String) throws -> [DerivedIndex] {
        guard let define = rebuildableDefinition(for: table) else { return [] }
        return try expectedDerivedIndexes(on: table, define: define)
    }

    static func expectedDerivedIndexes(on table: String, define: (TableDefinition) -> Void) throws -> [DerivedIndex] {
        let scratch = try DatabaseQueue()
        return try scratch.write { db in
            // `.references("Place")` makes GRDB look up the referenced table's primary key at
            // definition time, so each referenced table needs a stub here. Learned from the
            // error rather than listed by hand: a definition that references a new table keeps
            // working, and a reference that fails for any other reason still throws.
            var attempts = 0
            while true {
                do {
                    try db.create(table: table, body: define)
                    break
                } catch let error as DatabaseError where error.message?.hasPrefix("no such table: ") == true && attempts < 8 {
                    attempts += 1
                    let referenced = String(error.message!.dropFirst("no such table: ".count))
                    try db.execute(sql: "CREATE TABLE IF NOT EXISTS \"\(referenced)\" (\"id\" TEXT PRIMARY KEY)")
                }
            }
            return try derivedIndexes(on: table, in: db)
        }
    }

    /// `PRAGMA index_list` entries created by CREATE INDEX (origin `c`), with their columns.
    private static func derivedIndexes(on table: String, in db: GRDB.Database) throws -> [DerivedIndex] {
        var result: [DerivedIndex] = []
        for row in try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(table)\")") {
            let name: String = row["name"]
            let origin: String = row["origin"]
            guard origin == "c" else { continue }
            let columns: [String] = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(name)\")")
                .compactMap { $0["name"] as String? }
            guard !columns.isEmpty else { continue }
            result.append(DerivedIndex(name: name, columns: columns,
                                       unique: (row["unique"] as Int64? ?? 0) == 1))
        }
        return result
    }

    /// The name a derived index carries after a rebuild's rename: SQLite has no ALTER INDEX
    /// RENAME, so an index created on `<table>_new` keeps `<table>_new_on_<column>`.
    static func strayName(for index: DerivedIndex, on table: String) -> String {
        "\(table)_new_" + index.name.dropFirst("\(table)_".count)
    }

    /// Derived indexes absent from the live schema, per rebuildable table. Feeds the audit, the
    /// repair, and the repair's free-space guard, so all three agree on what is missing.
    static func missingDerivedIndexes(in db: GRDB.Database) throws -> [(table: String, missing: [DerivedIndex])] {
        let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        let liveIndexes = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'"))
        var result: [(table: String, missing: [DerivedIndex])] = []
        for table in tables.sorted() where rebuildableDefinition(for: table) != nil {
            let missing = try expectedDerivedIndexes(on: table).filter { !liveIndexes.contains($0.name) }
            if !missing.isEmpty { result.append((table: table, missing: missing)) }
        }
        return result
    }

    /// Replace every stray `<table>_new_on_x` index on a table with its canonical name, on ANY
    /// table (a rebuild of a table with no registered definition still leaves strays): create the
    /// canonical index FIRST, from the stray's own columns, then drop the stray. If the canonical
    /// already exists — installs that ran a `CREATE INDEX` migration after the rebuild that
    /// orphaned the stray carry both — only the drop happens.
    ///
    /// BIG-792: the previous form dropped first and created second, inside a migration whose
    /// per-table `catch` kept the transaction open. On a full disk the CREATE failed, the DROP
    /// stayed committed, and a 7 GB samples table was left with no index on `timelineItemId` —
    /// which nothing could detect, because derived indexes were not in the registry. Now a
    /// failure can only ever leave a duplicate, and out-of-space is not tolerated here at all:
    /// it propagates, so the caller's transaction rolls back and the repair retries when there
    /// is room.
    static func replaceStrayIndexes(on table: String, in db: GRDB.Database) throws {
        let strayPrefix = "\(table)_new_"
        for row in try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(table)\")") {
            let stray: String = row["name"]
            let origin: String = row["origin"]
            guard origin == "c", stray.hasPrefix(strayPrefix) else { continue }
            if (row["partial"] as Int64? ?? 0) == 1 {
                Log.error("schema rebuild: skipping partial index \(stray) (predicate not recoverable)", subsystem: .database)
                continue
            }
            let canonical = "\(table)_" + stray.dropFirst(strayPrefix.count)
            let unique = (row["unique"] as Int64? ?? 0) == 1
            let columns: [String] = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(stray)\")")
                .compactMap { $0["name"] as String? }
            guard !columns.isEmpty else { continue }
            do {
                try db.create(index: canonical, on: table, columns: columns,
                              options: unique ? [.ifNotExists, .unique] : [.ifNotExists])
                try db.execute(sql: "DROP INDEX IF EXISTS \"\(stray)\"")
                Log.info("schema rebuild: \(canonical) in place, dropped \(stray)", subsystem: .database)
            } catch let error as DatabaseError where StorageHealthMonitor.isOutOfSpace(error.resultCode) {
                Log.error("schema rebuild: out of space replacing \(stray): \(error)", subsystem: .database)
                throw error
            } catch {
                Log.error("schema rebuild: replacing \(stray) failed: \(error)", subsystem: .database)
            }
        }
    }

    /// Create any derived index the table's definition says it should have and the live schema
    /// lacks (after `replaceStrayIndexes` has renamed what could be renamed). Same tolerance
    /// rule: everything is logged and skipped except out-of-space, which propagates.
    static func createMissingDerivedIndexes(on table: String, in db: GRDB.Database,
                                            define: (TableDefinition) -> Void) throws {
        let expected = try expectedDerivedIndexes(on: table, define: define)
        guard !expected.isEmpty else { return }
        let live = Set(try String.fetchAll(
            db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?", arguments: [table]))
        for index in expected where !live.contains(index.name) {
            do {
                try db.create(index: index.name, on: table, columns: index.columns,
                              options: index.unique ? [.ifNotExists, .unique] : [.ifNotExists])
                Log.info("schema rebuild: created missing \(index.name)", subsystem: .database)
            } catch let error as DatabaseError where StorageHealthMonitor.isOutOfSpace(error.resultCode) {
                Log.error("schema rebuild: out of space creating \(index.name): \(error)", subsystem: .database)
                throw error
            } catch {
                Log.error("schema rebuild: creating \(index.name) failed: \(error)", subsystem: .database)
            }
        }
    }

    // MARK: - Launch-time repair

    public enum SchemaRepairOutcome: Sendable {
        case clean
        case repaired(seconds: Double)
        case postponed(neededBytes: Int64, availableBytes: Int64)
        case failed(String)
    }

    /// One index the repair has to build — from a stray it then drops, or from scratch.
    struct IndexBuild: Sendable {
        let table: String
        let name: String
        let columns: [String]
        let unique: Bool
        /// The stray to drop once the canonical is in place, when the build is a rename.
        let stray: String?
    }

    /// A stray whose canonical already exists: nothing to build, just a drop.
    struct StrayDrop: Sendable {
        let table: String
        let stray: String
        let canonical: String
    }

    struct SchemaRepairPlan: Sendable {
        var drops: [StrayDrop] = []
        var builds: [IndexBuild] = []
    }

    /// What the live schema needs, from one read: strays with a canonical twin (drop only),
    /// strays without one (build the canonical, then drop), derived indexes missing outright,
    /// and missing explicit indexes. Triggers are not planned; they are cheap and always applied.
    static func repairPlan(in db: GRDB.Database) throws -> SchemaRepairPlan {
        var plan = SchemaRepairPlan()
        let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'").sorted()
        let live = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'"))
        var planned = Set<String>()

        for table in tables {
            let strayPrefix = "\(table)_new_"
            for row in try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(table)\")") {
                let stray: String = row["name"]
                let origin: String = row["origin"]
                guard origin == "c", stray.hasPrefix(strayPrefix) else { continue }
                if (row["partial"] as Int64? ?? 0) == 1 {
                    Log.error("schema repair: skipping partial index \(stray) (predicate not recoverable)", subsystem: .database)
                    continue
                }
                let canonical = "\(table)_" + stray.dropFirst(strayPrefix.count)
                if live.contains(canonical) {
                    plan.drops.append(StrayDrop(table: table, stray: stray, canonical: canonical))
                } else {
                    let columns: [String] = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(stray)\")")
                        .compactMap { $0["name"] as String? }
                    guard !columns.isEmpty else { continue }
                    plan.builds.append(IndexBuild(table: table, name: canonical, columns: columns,
                                                  unique: (row["unique"] as Int64? ?? 0) == 1, stray: stray))
                    planned.insert(canonical)
                }
            }
        }
        for table in tables {
            guard let define = rebuildableDefinition(for: table) else { continue }
            for index in try expectedDerivedIndexes(on: table, define: define)
            where !live.contains(index.name) && !planned.contains(index.name) {
                plan.builds.append(IndexBuild(table: table, name: index.name, columns: index.columns,
                                              unique: index.unique, stray: nil))
                planned.insert(index.name)
            }
        }
        for index in allIndexDefinitions where tables.contains(index.table) && !live.contains(index.name) {
            plan.builds.append(IndexBuild(table: index.table, name: index.name, columns: index.columns,
                                          unique: index.unique, stray: nil))
        }
        return plan
    }

    /// Drop a stray whose canonical exists — only if the two agree on columns and uniqueness.
    static func drop(_ drop: StrayDrop, in db: GRDB.Database) throws {
        func shape(_ name: String) throws -> ([String], Bool) {
            let columns: [String] = try Row.fetchAll(db, sql: "PRAGMA index_info(\"\(name)\")").compactMap { $0["name"] as String? }
            let unique = try Row.fetchAll(db, sql: "PRAGMA index_list(\"\(drop.table)\")")
                .first { ($0["name"] as String) == name }
                .map { ($0["unique"] as Int64? ?? 0) == 1 } ?? false
            return (columns, unique)
        }
        let (strayColumns, strayUnique) = try shape(drop.stray)
        let (canonicalColumns, canonicalUnique) = try shape(drop.canonical)
        guard strayColumns == canonicalColumns, strayUnique == canonicalUnique else {
            Log.error("schema repair: keeping \(drop.stray) — \(drop.canonical) exists with different columns", subsystem: .database)
            return
        }
        try db.execute(sql: "DROP INDEX IF EXISTS \"\(drop.stray)\"")
        Log.info("schema repair: dropped duplicate \(drop.stray) (\(drop.canonical) already in place)", subsystem: .database)
    }

    /// Create one canonical index, then drop the stray it replaces, if any. One transaction per
    /// call, so a failure loses only this index's work and can never leave a hole.
    static func perform(_ build: IndexBuild, in db: GRDB.Database) throws {
        try db.create(index: build.name, on: build.table, columns: build.columns,
                      options: build.unique ? [.ifNotExists, .unique] : [.ifNotExists])
        if let stray = build.stray {
            try db.execute(sql: "DROP INDEX IF EXISTS \"\(stray)\"")
            Log.info("schema repair: \(build.name) in place, dropped \(stray)", subsystem: .database)
        } else {
            Log.info("schema repair: created missing \(build.name)", subsystem: .database)
        }
    }

    /// Every registry trigger whose table exists, IF NOT EXISTS. Cheap; always applied last.
    static func createMissingTriggers(in db: GRDB.Database) throws {
        let tables = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'"))
        let live = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'"))
        for trigger in allTriggerDefinitions where tables.contains(trigger.table) && !live.contains(trigger.name) {
            try db.execute(sql: trigger.createSQL)
            Log.info("schema repair: created missing trigger \(trigger.name)", subsystem: .database)
        }
    }

    /// Audit the live schema and, only if it has defects, repair it. Runs at every launch after
    /// migrations (the audit is milliseconds when clean); the app shows its migration cover
    /// around the repair via `whileRepairing`, since an index build on a large database takes
    /// minutes. Deliberately NOT a migration (BIG-792): a migration that throws to retry later
    /// blocks every migration registered after it, and one that swallows the failure commits
    /// whatever half-state SQLite left.
    ///
    /// The work is done in small transactions — duplicate strays dropped first (near free), then
    /// ONE index build per transaction, each behind its own free-space check, then triggers —
    /// so a device short of space makes progress an index at a time, a failure loses only the
    /// index in flight, and peak disk is about one index rather than all of them at once. A
    /// postponed build logs one loud line and is retried at the next launch for the price of an
    /// audit; the previous shape spent ~20 s per launch on a CREATE INDEX that could not succeed.
    public func repairSchemaIfNeeded(whileRepairing: @Sendable (Bool) async -> Void = { _ in }) async -> SchemaRepairOutcome {
        let audit: SchemaAudit
        let plan: SchemaRepairPlan
        do {
            audit = try await pool.read { try Database.auditSchema(in: $0) }
            guard !audit.isClean else { return .clean }
            Log.info("schema repair: \(audit.summary)", subsystem: .database)
            plan = try await pool.read { try Database.repairPlan(in: $0) }
        } catch {
            Log.error("schema repair: audit failed: \(error)", subsystem: .database)
            return .failed("\(error)")
        }

        await whileRepairing(true)
        let start = Date()
        var outcome: SchemaRepairOutcome = .repaired(seconds: 0)

        if !plan.drops.isEmpty {
            do {
                try await pool.write { db in for drop in plan.drops { try Database.drop(drop, in: db) } }
            } catch {
                Log.error("schema repair: dropping duplicate strays failed, rolled back: \(error)", subsystem: .database)
                outcome = .failed("\(error)")
            }
        }

        var rowCounts: [String: Int] = [:]
        for build in plan.builds {
            guard case .repaired = outcome else { break }
            if rowCounts[build.table] == nil {
                rowCounts[build.table] = (try? await pool.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM \"\(build.table)\"") }) ?? 0
            }
            let needed = Database.estimatedIndexBuildBytes(rows: rowCounts[build.table] ?? 0)
            if let available = Database.availableCapacity(at: pool.path), available < needed {
                Log.error("schema repair: postponed at \(build.name) — needs ~\(needed / 1_048_576) MB free, \(available / 1_048_576) MB available", subsystem: .database)
                outcome = .postponed(neededBytes: needed, availableBytes: available)
                break
            }
            do {
                try await pool.write { db in try Database.perform(build, in: db) }
            } catch {
                Log.error("schema repair: \(build.name) failed, rolled back: \(error)", subsystem: .database)
                outcome = .failed("\(error)")
            }
        }

        if case .repaired = outcome {
            do {
                try await pool.write { db in try Database.createMissingTriggers(in: db) }
            } catch {
                Log.error("schema repair: triggers failed, rolled back: \(error)", subsystem: .database)
                outcome = .failed("\(error)")
            }
        }

        let seconds = -start.timeIntervalSinceNow
        if let after = try? await pool.read({ try Database.auditSchema(in: $0) }) {
            if after.isClean {
                Log.info("schema repair: repaired in \(String(format: "%.1f", seconds))s", subsystem: .database)
            } else {
                Log.error("schema repair: after \(String(format: "%.1f", seconds))s, \(after.summary)", subsystem: .database)
            }
        }
        if case .repaired = outcome { outcome = .repaired(seconds: seconds) }
        await whileRepairing(false)
        return outcome
    }

    // MARK: - Free space

    /// Bytes genuinely free on the volume holding `path` (not counting purgeable space, which
    /// iOS does not free synchronously for SQLite's writes), or nil if it can't be read.
    static func availableCapacity(at path: String) -> Int64? {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacity.map(Int64.init)
    }

    /// Headroom for ONE single-column index build in its own transaction: 48 bytes a row
    /// (measured on a 7.5M-sample copy: 45 for `timelineItemId`, 59 for the widest composite)
    /// for the index itself, the same again for the WAL it is written through, the same again
    /// for the sorter's temp file, plus a fixed margin.
    static func estimatedIndexBuildBytes(rows: Int) -> Int64 {
        Int64(rows) * 48 * 3 + 64 * 1024 * 1024
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
        let missingExplicit = allIndexDefinitions
            .filter { tables.contains($0.table) && !liveIndexes.contains($0.name) }
            .map(\.name)
        // BIG-792: derived indexes too — a rebuild's failed rename is invisible without this
        let missingDerived = try missingDerivedIndexes(in: db).flatMap { $0.missing.map(\.name) }
        let missingIndexes = missingExplicit + missingDerived
        let strayIndexes = liveIndexes.filter { name in
            tables.contains { name.hasPrefix("\($0)_new_") }
        }
        return SchemaAudit(missingTriggers: missingTriggers.sorted(),
                           missingIndexes: missingIndexes.sorted(),
                           strayIndexes: strayIndexes.sorted())
    }
}
