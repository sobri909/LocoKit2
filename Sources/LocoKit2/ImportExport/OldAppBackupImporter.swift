//
//  OldAppBackupImporter.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation
import GRDB

/// Imports the old app's (Arc Timeline 3) iCloud backup sets directly into LocoKit2, without
/// the old app being installed (BIG-399). Design record: `docs/planning/BIG-399-design-decisions.md`.
///
/// The walk is the old app's own, minus its bugs: the sample-week files drive everything
/// (they are the only files whose names carry dates), and each item is pulled in the first time
/// a sample references it, each place the first time a visit references it. Item dates are read
/// from the item files rather than nilled. Every set found under the picked folder is unioned
/// in one run (a set is a change-log, not a snapshot; the user's history is the union of all
/// their sets), with the newest `lastSaved` winning per record and a nil `lastSaved` never
/// overwriting. Each week is one transaction and one checkpoint; a resume re-runs the current
/// week idempotently. Deleted records are skipped. Item files no sample ever references are
/// counted and not imported (they would be dateless shells). Read-only over the files;
/// additive (insert-or-ignore by id) into the database, so it composes with Migrate.
@ImportExportActor
public enum OldAppBackupImporter {

    // MARK: - Observable state

    public private(set) static var importInProgress = false
    public private(set) static var progress: Double = 0
    public private(set) static var currentPhase: Phase?
    /// "2021-W36 (123 of 453)" while weeks are landing
    public private(set) static var currentWeekLabel: String?
    public private(set) static var lastSummary: Summary?

    public enum Phase: Sendable {
        case discovering, importingWeeks, finishing

        public var description: String {
            switch self {
            case .discovering: return "Reading backup folders"
            case .importingWeeks: return "Importing timeline data"
            case .finishing: return "Finishing up"
            }
        }
    }

    public struct Summary: Sendable {
        public var sets = 0
        public var weeksTotal = 0
        public var weeksProcessed = 0
        public var weeksDeferred = 0        // files not downloaded from iCloud; not marked processed
        public var weeksSkippedAfterCutoff = 0
        public var samplesImported = 0
        public var samplesAfterCutoff = 0
        public var samplesAlreadyPresent = 0
        public var samplesDeleted = 0
        public var samplesOfDeletedItems = 0
        public var samplesUndecodable = 0
        public var itemsImported = 0
        public var itemsAlreadyPresent = 0
        public var itemsDeleted = 0
        public var itemsMissingFile = 0     // referenced by a sample, no file in any set → orphan path
        public var itemsUnreferenced = 0    // file exists, no sample references it → not imported
        public var itemsUnconvertible = 0
        public var placesImported = 0
        public var placesAlreadyPresent = 0
        public var placesMissingFile = 0    // visit references a place no set holds → placeless visit
        public var placesUnconvertible = 0
        public var orphanSamples = 0
        public var orphanItemsRecreated = 0
        public var orphanIndividualItems = 0

        public var description: String {
            "\(sets) sets, \(weeksProcessed)/\(weeksTotal) weeks (\(weeksDeferred) deferred, \(weeksSkippedAfterCutoff) after cutoff); "
            + "samples \(samplesImported) imported, \(samplesAlreadyPresent) present, \(samplesAfterCutoff) after cutoff, \(samplesDeleted) deleted, \(samplesOfDeletedItems) of deleted items, \(samplesUndecodable) undecodable; "
            + "items \(itemsImported) imported, \(itemsAlreadyPresent) present, \(itemsDeleted) deleted, \(itemsMissingFile) missing files, \(itemsUnreferenced) unreferenced, \(itemsUnconvertible) unconvertible; "
            + "places \(placesImported) imported, \(placesAlreadyPresent) present, \(placesMissingFile) missing files, \(placesUnconvertible) unconvertible; "
            + "orphans \(orphanSamples) samples → \(orphanItemsRecreated) items recreated, \(orphanIndividualItems) individual"
        }
    }

    // MARK: - Run state

    private static var wasObserving = true
    private static var wasRecording = false
    private static var summary = Summary()

    /// items already handled in THIS run (imported, found present, or found deleted / missing)
    private static var handledItemIds = Set<String>()
    /// items whose union record says deleted: their samples are dead data, skipped
    private static var deletedItemIds = Set<String>()
    private static var handledPlaceIds = Set<String>()

    /// scenario-2 samples (disabled samples under an enabled parent) waiting for a preserved
    /// parent; flushed before each week is checkpointed, so a kill loses at most one week's
    private static var disabledSamplesFromEnabledParents: [String: [LocomotionSample]] = [:]

    /// everything a week mutates before its transaction commits, so a deferred week (a file
    /// not yet downloaded) can be rolled back and the next attempt sees it untouched
    private struct WeekState {
        let handledItemIds: Set<String>
        let deletedItemIds: Set<String>
        let handledPlaceIds: Set<String>
        let summary: Summary
    }

    /// consecutive deferred weeks before the run gives up on this attempt: offline, every
    /// week would otherwise wait out the full download timeout
    private static let maxConsecutiveDeferrals = 5

    // MARK: - Public interface

    /// Start a fresh import from a folder the user picked (the caller holds the security scope
    /// for the duration of this call; a bookmark is kept for resumes).
    ///
    /// `before` is Migrate's parallel-era window: only records dated before it are imported, so
    /// a user who kept the old app recording beside AT4 doesn't get those days twice. Pass the
    /// earliest AT4-recorded date, or nil for a phone AT4 has never recorded on. Overlap-aware
    /// import is a different class of importer (the GPX / workout shape) and a separate ticket.
    public static func startImport(from parentURL: URL, before cutoff: Date?) async throws {
        guard !importInProgress else { throw ImportExportError.importAlreadyInProgress }

        await beginRun()
        do {
            currentPhase = .discovering
            let sets = LegacyBackup.BackupSet.discover(in: parentURL)
            guard !sets.isEmpty else { throw ImportExportError.noBackupSetsFound }
            Log.info("OldAppBackupImporter: \(sets.count) set(s) under \(parentURL.lastPathComponent): \(sets.map(\.name).joined(separator: ", ")); cutoff \(cutoff.map { "\($0)" } ?? "none")", subsystem: .importing)

            let weeks = weekPlan(for: sets)
            try checkFreeSpace(for: weeks)

            let bookmark = try parentURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            let state = OldAppBackupImportState(sourceBookmark: bookmark, totalWeekCount: weeks.count, cutoffDate: cutoff)
            try await OldAppBackupImportState.save(state)
            try await OldAppBackupImportState.recordAttemptStart()

            try await run(sets: sets, weeks: weeks, alreadyProcessed: [], cutoff: cutoff)

        } catch {
            Log.error("OldAppBackupImporter failed: \(error)", subsystem: .importing)
            try? await OldAppBackupImportState.recordError(error)
            endRun()
            throw error
        }
    }

    /// Resume an interrupted import from the bookmarked folder.
    public static func resumeImport() async throws {
        guard !importInProgress else { throw ImportExportError.importAlreadyInProgress }
        guard let state = try await OldAppBackupImportState.current() else {
            throw ImportExportError.importNotInitialised
        }

        await beginRun()
        do {
            currentPhase = .discovering
            var stale = false
            guard let parentURL = try? URL(resolvingBookmarkData: state.sourceBookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
                throw ImportExportError.invalidBookmark
            }
            guard parentURL.startAccessingSecurityScopedResource() else {
                throw ImportExportError.securityScopeAccessDenied
            }
            defer { parentURL.stopAccessingSecurityScopedResource() }

            let sets = LegacyBackup.BackupSet.discover(in: parentURL)
            guard !sets.isEmpty else { throw ImportExportError.noBackupSetsFound }
            let weeks = weekPlan(for: sets)
            try checkFreeSpace(for: weeks.filter { !state.processedWeekStems.contains($0.stem) })
            Log.info("OldAppBackupImporter: resuming, \(state.processedWeekStems.count)/\(weeks.count) weeks done", subsystem: .importing)

            try await OldAppBackupImportState.recordAttemptStart()
            try await run(sets: sets, weeks: weeks, alreadyProcessed: Set(state.processedWeekStems), cutoff: state.cutoffDate)

        } catch {
            Log.error("OldAppBackupImporter resume failed: \(error)", subsystem: .importing)
            try? await OldAppBackupImportState.recordError(error)
            endRun()
            throw error
        }
    }

    /// The bookmarked source folder of an interrupted import, with security-scoped access
    /// STARTED: the caller owns the matching `stopAccessingSecurityScopedResource()`. For work
    /// the app does over the same files after a resume (the notes phase lives in the app).
    public static func resolveSourceURL() async throws -> URL {
        guard let state = try await OldAppBackupImportState.current() else {
            throw ImportExportError.importNotInitialised
        }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: state.sourceBookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            throw ImportExportError.invalidBookmark
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportExportError.securityScopeAccessDenied
        }
        return url
    }

    // MARK: - The run

    /// One week stem and the file for it in every set that has one.
    struct WeekPlan {
        let stem: String
        let files: [LegacyBackup.SampleWeekFile]
    }

    /// What one week's transaction did, read back out of the write closure.
    struct WeekCounts: Sendable {
        var placesImported = 0, placesPresent = 0, placesFailed = 0
        var itemsImported = 0, itemsPresent = 0, itemsFailed = 0
        var samplesInserted = 0
        var orphansRecreated = 0, orphansIndividual = 0
    }

    private static func weekPlan(for sets: [LegacyBackup.BackupSet]) -> [WeekPlan] {
        var byStem: [String: [LegacyBackup.SampleWeekFile]] = [:]
        for set in sets {
            for week in set.sampleWeekFiles() {
                byStem[week.stem, default: []].append(week)
            }
        }
        return byStem.keys.sorted().map { WeekPlan(stem: $0, files: byStem[$0]!) }
    }

    /// Refuse to start without room: a gzipped week expands roughly tenfold into JSON and lands
    /// in the database at roughly 1.5× its gzipped size, WAL included. Nothing in the import
    /// path guarded this before; a full-disk failure mid-import is the worst outcome.
    private static func checkFreeSpace(for weeks: [WeekPlan]) throws {
        let gzBytes = weeks.flatMap(\.files).reduce(Int64(0)) { total, file in
            let size = (try? file.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
        let needed = gzBytes * 2 + 512 * 1024 * 1024
        if let available = Database.availableCapacity(at: Database.pool.path), available < needed {
            Log.error("OldAppBackupImporter: refusing to start — needs ~\(needed / 1_048_576) MB free for \(gzBytes / 1_048_576) MB of sample files, \(available / 1_048_576) MB available", subsystem: .importing)
            throw ImportExportError.insufficientFreeSpace
        }
    }

    private static func run(sets: [LegacyBackup.BackupSet], weeks: [WeekPlan], alreadyProcessed: Set<String>, cutoff: Date?) async throws {
        let startTime = Date()
        summary.sets = sets.count
        summary.weeksTotal = weeks.count
        summary.weeksProcessed = alreadyProcessed.count

        currentPhase = .importingWeeks
        var consecutiveDeferrals = 0
        for (index, week) in weeks.enumerated() {
            if alreadyProcessed.contains(week.stem) { continue }
            currentWeekLabel = "\(week.stem) (\(index + 1) of \(weeks.count))"
            progress = Double(index) / Double(max(weeks.count, 1))

            // a week that starts at or after the cutoff has nothing to import; mark it done
            // without opening it (the stem is a date; an unparseable stem is opened and filtered)
            if let cutoff, let weekStart = week.files.first?.weekStart, weekStart >= cutoff {
                try await OldAppBackupImportState.markWeekProcessed(week.stem)
                summary.weeksProcessed += 1
                summary.weeksSkippedAfterCutoff += 1
                continue
            }

            let landed = try await importWeek(week, sets: sets, cutoff: cutoff)
            if landed {
                // preserved parents for this week's scenario-2 samples go in BEFORE the
                // checkpoint: after it, a kill would leave them parentless and the week "done"
                try await flushPreservedParents()
                try await OldAppBackupImportState.markWeekProcessed(week.stem)
                summary.weeksProcessed += 1
                consecutiveDeferrals = 0
            } else {
                summary.weeksDeferred += 1
                consecutiveDeferrals += 1
                if consecutiveDeferrals >= maxConsecutiveDeferrals {
                    Log.error("OldAppBackupImporter: \(consecutiveDeferrals) weeks deferred in a row — files not downloading; stopping this attempt", subsystem: .importing)
                    throw ImportExportError.backupFilesNotDownloaded
                }
            }
        }

        currentPhase = .finishing
        currentWeekLabel = nil

        // decision 1's count: item files no sample in any set references. Not imported.
        var allItemIds = Set<String>()
        for set in sets { allItemIds.formUnion(set.recordIds(in: "TimelineItem")) }
        summary.itemsUnreferenced = allItemIds.subtracting(handledItemIds).count

        progress = 1
        let minutes = String(format: "%.1f", Date().timeIntervalSince(startTime) / 60)
        Log.info("OldAppBackupImporter completed in \(minutes) min: \(summary.description)", subsystem: .importing)
        lastSummary = summary

        if summary.weeksDeferred > 0 {
            // not done: iCloud placeholders stood in for files we needed. Keep the state row so a
            // later attempt picks those weeks up once the Files app has downloaded them.
            Log.error("OldAppBackupImporter: \(summary.weeksDeferred) week(s) deferred — files not downloaded from iCloud", subsystem: .importing)
            throw ImportExportError.backupFilesNotDownloaded
        }

        try await OldAppBackupImportState.clear()
        endRun()
    }

    /// Preserved parents for scenario-2 samples (`ImportHelpers` runs its own transaction, so
    /// this sits between a week's transaction and its checkpoint rather than inside it).
    private static func flushPreservedParents() async throws {
        guard !disabledSamplesFromEnabledParents.isEmpty else { return }
        try await ImportHelpers.createPreservedParentItems(for: disabledSamplesFromEnabledParents)
        disabledSamplesFromEnabledParents = [:]
    }

    /// One item per missing original item, visit or trip by majority moving state, created in
    /// the same transaction as the samples so a kill cannot leave them parentless behind a
    /// checkpoint. NOT the shared `OrphanedSampleProcessor`: its mixed-moving-state branch makes
    /// one item PER SAMPLE for the whole group, tolerable for Migrate's rare orphans and 80k
    /// one-sample items from a single partial set here, where a missing item file is routine
    /// (a set is a change-log; its items often live in another set). A group split at a week
    /// boundary becomes two items; timeline processing merges those. Source is "LocoKit" so the
    /// migration gates recognise them as old-app data.
    nonisolated private static func recreateOrphanGroups(_ groups: [String: [LocomotionSample]], db: GRDB.Database) -> (recreated: Int, individual: Int) {
        var recreated = 0, individual = 0
        for (originalItemId, samples) in groups {
            let sorted = samples.sorted { $0.date < $1.date }
            let stationary = sorted.filter { $0.movingState == .stationary }.count
            let isVisit = stationary * 2 >= sorted.count
            do {
                try db.inSavepoint {
                    _ = try TimelineItem.createItem(from: sorted, isVisit: isVisit, source: "LocoKit", db: db)
                    return .commit
                }
                if sorted.count < TimelineItemTrip.minimumValidSamples { individual += 1 } else { recreated += 1 }
            } catch {
                Log.error("OldAppBackupImporter: skipping orphan group \(originalItemId) (\(sorted.count) samples): \(error)", subsystem: .importing)
            }
        }
        return (recreated, individual)
    }

    // MARK: - One week

    /// Everything one week stem needs, in one transaction: the places its visits reference, the
    /// items its samples reference, then the samples. Returns false (and writes nothing) if a
    /// file the week needs is an iCloud placeholder that couldn't be materialised.
    private static func importWeek(_ week: WeekPlan, sets: [LegacyBackup.BackupSet], cutoff: Date?) async throws -> Bool {
        let decoder = LegacyBackup.decoder()

        // nothing this week does to the run's bookkeeping survives a deferral
        let before = WeekState(handledItemIds: handledItemIds, deletedItemIds: deletedItemIds, handledPlaceIds: handledPlaceIds, summary: summary)
        func defer_(_ what: String) -> Bool {
            Log.info("OldAppBackupImporter: \(week.stem) deferred — \(what) not local", subsystem: .importing)
            handledItemIds = before.handledItemIds
            deletedItemIds = before.deletedItemIds
            handledPlaceIds = before.handledPlaceIds
            summary = before.summary
            return false
        }

        // 1. read and union this week's samples across sets (newest lastSaved wins; nil never overwrites)
        var unioned: [String: LegacyBackup.Sample] = [:]
        for file in week.files {
            let gz: Data
            switch await readFile(at: file.url) {
            case .data(let data): gz = data
            case .notLocal: return defer_(file.url.lastPathComponent)
            case .failed: continue  // logged by readFile; a copy in another set may still serve
            }
            let json: Data
            do { json = try gz.gzipDecompressed() } catch {
                Log.error("OldAppBackupImporter: \(file.url.lastPathComponent) failed to decompress: \(error)", subsystem: .importing)
                continue
            }
            let elements: [LegacyBackup.Lenient<LegacyBackup.Sample>]
            do { elements = try decoder.decode([LegacyBackup.Lenient<LegacyBackup.Sample>].self, from: json) } catch {
                Log.error("OldAppBackupImporter: \(file.url.lastPathComponent) is not a sample array: \(error)", subsystem: .importing)
                continue
            }
            for element in elements {
                guard let sample = element.value else { summary.samplesUndecodable += 1; continue }
                if let cutoff, sample.date >= cutoff { summary.samplesAfterCutoff += 1; continue }
                merge(sample, into: &unioned, id: sample.sampleId, lastSaved: sample.lastSaved)
            }
        }

        // 2. the items the LIVE samples reference, and the places those items reference. An
        //    item referenced only by deleted samples would land as a dateless shell (dates in
        //    LocoKit2 derive from samples), which is the class decision 1 exists to exclude.
        let liveSamples = unioned.values.filter { !$0.isDeleted }
        summary.samplesDeleted += unioned.count - liveSamples.count
        let referencedItemIds = Set(liveSamples.compactMap(\.timelineItemId))
        let newItemIds = referencedItemIds.subtracting(handledItemIds)
        var itemsToInsert: [LegacyItem] = []
        var placesToInsert: [LegacyPlace] = []
        for itemId in newItemIds.sorted() {
            guard let outcome = try await readUnioned(LegacyBackup.Item.self, id: itemId, in: sets, fileURL: { $0.itemFileURL(for: itemId) }, recordId: \.itemId, lastSaved: \.lastSaved) else {
                return defer_("item \(itemId)")  // a copy exists only as a placeholder
            }
            handledItemIds.insert(itemId)
            switch outcome {
            case .none:
                summary.itemsMissingFile += 1
            case .some(let item):
                if item.isDeleted {
                    deletedItemIds.insert(itemId)
                    summary.itemsDeleted += 1
                    continue
                }
                itemsToInsert.append(LegacyItem(backup: item))
                if item.isVisit, let placeId = item.placeId, !handledPlaceIds.contains(placeId) {
                    guard let placeOutcome = try await readUnioned(LegacyBackup.Place.self, id: placeId, in: sets, fileURL: { $0.placeFileURL(for: placeId) }, recordId: \.placeId, lastSaved: \.lastSaved) else {
                        return defer_("place \(placeId)")
                    }
                    handledPlaceIds.insert(placeId)
                    if let place = placeOutcome {
                        placesToInsert.append(LegacyPlace(backup: place))
                    } else {
                        summary.placesMissingFile += 1
                    }
                }
            }
        }

        // 3. convert the samples that will be inserted
        var samples: [LocomotionSample] = []
        samples.reserveCapacity(liveSamples.count)
        for legacy in liveSamples {
            if let itemId = legacy.timelineItemId, deletedItemIds.contains(itemId) { summary.samplesOfDeletedItems += 1; continue }
            samples.append(LocomotionSample(from: LegacySample(backup: legacy)))
        }
        samples.sort { $0.date < $1.date }

        // 4. one transaction for the week
        let stem = week.stem
        let (batchResult, counts) = try await Database.pool.write { [placesToInsert, itemsToInsert, samples] db -> (SampleBatchResult, WeekCounts) in
            var placesImported = 0, placesPresent = 0, placesFailed = 0
            for legacyPlace in placesToInsert {
                do {
                    try db.inSavepoint {
                        try Place(from: legacyPlace).insert(db, onConflict: .ignore)
                        if db.changesCount == 1 { placesImported += 1 } else { placesPresent += 1 }
                        return .commit
                    }
                } catch {
                    placesFailed += 1
                    Log.error("OldAppBackupImporter: skipping place \(legacyPlace.placeId): \(error)", subsystem: .importing)
                }
            }

            var itemsImported = 0, itemsPresent = 0, itemsFailed = 0
            for legacyItem in itemsToInsert {
                do {
                    let item = try TimelineItem(from: legacyItem)
                    try db.inSavepoint {
                        try item.base.insert(db, onConflict: .ignore)
                        let inserted = db.changesCount == 1
                        if let visit = item.visit {
                            var visit = visit
                            if let placeId = visit.placeId, try Place.filter({ $0.id == placeId }).fetchCount(db) == 0 {
                                // the set never held this place (zero-visit places were never backed up)
                                visit.clearPlace()
                            }
                            try visit.insert(db, onConflict: .ignore)
                        }
                        try item.trip?.insert(db, onConflict: .ignore)
                        if inserted { itemsImported += 1 } else { itemsPresent += 1 }
                        return .commit
                    }
                } catch {
                    itemsFailed += 1
                    Log.error("OldAppBackupImporter: skipping item \(legacyItem.itemId): \(error)", subsystem: .importing)
                }
            }

            // parent truth comes from the database, not the files: an item may already be here
            // from Migrate (possibly since edited), and its current disabled state is the one
            // the samples must agree with (BIG-629)
            let referenced = Array(Set(samples.compactMap(\.timelineItemId)))
            var validItemIds = Set<String>()
            var disabledStates: [String: Bool] = [:]
            if !referenced.isEmpty {
                let rows = try Row.fetchAll(db, TimelineItemBase
                    .filter(referenced.contains(TimelineItemBase.Columns.id))
                    .filter(TimelineItemBase.Columns.deleted == false)
                    .select(TimelineItemBase.Columns.id, TimelineItemBase.Columns.disabled))
                for row in rows {
                    let id: String = row[0]
                    validItemIds.insert(id)
                    disabledStates[id] = row[1]
                }
            }

            var result = SampleBatchResult()
            for chunk in samples.chunked(into: 1000) {
                let chunkResult = try SampleImportProcessor.processBatch(
                    samples: chunk,
                    validItemIds: validItemIds,
                    itemDisabledStates: disabledStates,
                    orphanOnlyIfEnabled: true,
                    db: db
                )
                result.orphanCount += chunkResult.orphanCount
                result.scenario1Count += chunkResult.scenario1Count
                result.scenario2Count += chunkResult.scenario2Count
                result.insertedCount += chunkResult.insertedCount
                result.orphans.merge(chunkResult.orphans) { $0 + $1 }
                result.scenario2.merge(chunkResult.scenario2) { $0 + $1 }
            }

            // homes for this week's orphans, in the same transaction as the samples
            let (recreated, individual) = recreateOrphanGroups(result.orphans, db: db)

            return (result, WeekCounts(
                placesImported: placesImported, placesPresent: placesPresent, placesFailed: placesFailed,
                itemsImported: itemsImported, itemsPresent: itemsPresent, itemsFailed: itemsFailed,
                samplesInserted: result.insertedCount, orphansRecreated: recreated, orphansIndividual: individual
            ))
        }

        summary.placesImported += counts.placesImported
        summary.placesAlreadyPresent += counts.placesPresent
        summary.placesUnconvertible += counts.placesFailed
        summary.itemsImported += counts.itemsImported
        summary.itemsAlreadyPresent += counts.itemsPresent
        summary.itemsUnconvertible += counts.itemsFailed
        summary.samplesImported += counts.samplesInserted
        summary.samplesAlreadyPresent += samples.count - counts.samplesInserted
        summary.orphanSamples += batchResult.orphanCount
        summary.orphanItemsRecreated += counts.orphansRecreated
        summary.orphanIndividualItems += counts.orphansIndividual
        SampleImportProcessor.logBatchResults(batchResult)
        for (itemId, scenario2Samples) in batchResult.scenario2 {
            disabledSamplesFromEnabledParents[itemId, default: []] += scenario2Samples
        }

        Log.info("OldAppBackupImporter: \(stem) landed — \(samples.count) samples, \(itemsToInsert.count) items, \(placesToInsert.count) places, \(batchResult.orphanCount) orphans → \(counts.orphansRecreated + counts.orphansIndividual) items", subsystem: .importing)
        return true
    }

    // MARK: - Reading records across sets

    /// Newest `lastSaved` wins; a record without `lastSaved` never overwrites one that has it
    /// (the old app's own conflict rule); ties keep the first seen.
    private static func merge<T>(_ incoming: T, into store: inout [String: T], id: String, lastSaved: Date?) {
        guard let existing = store[id] else { store[id] = incoming; return }
        let existingSaved = existingLastSaved(existing)
        switch (existingSaved, lastSaved) {
        case (nil, .some): store[id] = incoming
        case (.some(let a), .some(let b)) where b > a: store[id] = incoming
        default: break
        }
    }

    private static func existingLastSaved<T>(_ value: T) -> Date? {
        if let sample = value as? LegacyBackup.Sample { return sample.lastSaved }
        if let item = value as? LegacyBackup.Item { return item.lastSaved }
        if let place = value as? LegacyBackup.Place { return place.lastSaved }
        return nil
    }

    /// Read one record id from every set and union the copies. Returns `nil` when a copy exists
    /// only as an un-materialised iCloud placeholder (defer, don't decide), `.some(nil)` when no
    /// set has the file at all, `.some(record)` otherwise. Undecodable copies are skipped and
    /// logged; if every copy is undecodable the record counts as missing.
    private static func readUnioned<T: Decodable & Sendable>(
        _ type: T.Type, id: String, in sets: [LegacyBackup.BackupSet],
        fileURL: (LegacyBackup.BackupSet) -> URL, recordId: KeyPath<T, String>, lastSaved: KeyPath<T, Date?>
    ) async throws -> T?? {
        let decoder = LegacyBackup.decoder()
        var winner: T?
        var sawFile = false
        for set in sets {
            let url = fileURL(set)
            let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
            guard FileManager.default.fileExists(atPath: url.path) || FileManager.default.fileExists(atPath: placeholder.path) else { continue }
            sawFile = true
            let data: Data
            switch await readFile(at: url) {
            case .data(let read): data = read
            case .notLocal: return nil
            case .failed: continue  // this copy is unreadable; another set's may not be
            }
            do {
                let record = try decoder.decode(T.self, from: data)
                // the filename is the index, the record's own id is its identity; a hand-copied
                // file can carry another record under this name (seen in a real user set). It
                // is not this record, so it is not a copy of it.
                guard record[keyPath: recordId] == id else {
                    Log.error("OldAppBackupImporter: \(url.lastPathComponent) in \(set.name) holds record \(record[keyPath: recordId]) — ignored", subsystem: .importing)
                    continue
                }
                if let current = winner {
                    switch (current[keyPath: lastSaved], record[keyPath: lastSaved]) {
                    case (nil, .some): winner = record
                    case (.some(let a), .some(let b)) where b > a: winner = record
                    default: break
                    }
                } else {
                    winner = record
                }
            } catch {
                Log.error("OldAppBackupImporter: undecodable \(url.lastPathComponent) in \(set.name): \(error)", subsystem: .importing)
                if T.self == LegacyBackup.Item.self { summary.itemsUnconvertible += 1 } else { summary.placesUnconvertible += 1 }
            }
        }
        if !sawFile { return .some(nil) }
        return winner.map { .some($0) } ?? .some(nil)
    }

    enum ReadOutcome {
        case data(Data)
        case notLocal   // an iCloud placeholder that didn't materialise in time: defer, retry later
        case failed     // unreadable (logged): skip this copy, never wait on it
    }

    /// Local files are read directly (an iCloud item that `fileExists` misreports falls
    /// through to the coordinated read rather than failing); placeholders go through the
    /// coordinated read, which kicks off the download and waits a bounded time.
    private static func readFile(at url: URL) async -> ReadOutcome {
        if FileManager.default.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) {
            return .data(data)
        }
        switch await iCloudCoordinator.readCoordinated(from: url, timeout: 20) {
        case .data(let data): return .data(data)
        case .notLocalYet: return .notLocal
        case .failed, .absent:
            Log.error("OldAppBackupImporter: cannot read \(url.lastPathComponent)", subsystem: .importing)
            return .failed
        }
    }

    // MARK: - Run bookkeeping

    private static func beginRun() async {
        importInProgress = true
        progress = 0
        currentPhase = nil
        currentWeekLabel = nil
        summary = Summary()
        handledItemIds = []
        deletedItemIds = []
        handledPlaceIds = []
        disabledSamplesFromEnabledParents = [:]

        // timeline processing and recording stay out of the way while rows land (the Migrate pattern)
        wasObserving = TimelineObserver.highlander.enabled
        TimelineObserver.highlander.enabled = false
        wasRecording = await TimelineRecorder.isRecording
        await TimelineRecorder.stopRecording()
    }

    private static func endRun() {
        TimelineObserver.highlander.enabled = wasObserving
        if wasRecording {
            Task { try? await TimelineRecorder.startRecording() }
        }
        importInProgress = false
        currentPhase = nil
        currentWeekLabel = nil
        disabledSamplesFromEnabledParents = [:]
    }
}
