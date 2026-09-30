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
///
/// **Copy first, always** (Day 167 decision 1): every record file the run reads is copied from the
/// picked folder into the app's container before a row is written, forcing iCloud to deliver
/// everything up front. A file iCloud can't deliver fails the copy, before the state row exists,
/// so the user is told and nothing is half-done. Import, resume and the app's notes phase all
/// read the local copy, which is removed when the run ends or the import is abandoned. Matt:
/// "can't trust iCloud Drive on a per file basis, once we're already into the import and can't
/// back out gracefully." Model: `ImportManager.copyToLocal` (the AT4 restore).
@ImportExportActor
public enum OldAppBackupImporter {

    // MARK: - Observable state

    public private(set) static var importInProgress = false
    public private(set) static var progress: Double = 0
    public private(set) static var currentPhase: Phase?
    /// "2021-W36 (123 of 453)" while weeks are landing; "12,000 of 400,000 files" while copying
    public private(set) static var currentWeekLabel: String?
    public private(set) static var lastSummary: Summary?

    public enum Phase: Sendable {
        case discovering, copying, importingWeeks, finishing

        public var description: String {
            switch self {
            case .discovering: return "Reading backup folders"
            case .copying: return "Copying backups to local storage"
            case .importingWeeks: return "Importing timeline data"
            case .finishing: return "Finishing up"
            }
        }
    }

    public struct Summary: Sendable {
        public var sets = 0
        public var filesCopied = 0
        public var bytesCopied: Int64 = 0
        public var weeksTotal = 0
        public var weeksProcessed = 0
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
            "\(sets) sets, \(filesCopied) files (\(bytesCopied / 1_048_576) MB) copied, \(weeksProcessed)/\(weeksTotal) weeks (\(weeksSkippedAfterCutoff) after cutoff); "
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

    // MARK: - Public interface

    /// Where the sets are copied to, and what import, resume and the app's notes phase read:
    /// `Documents/OldAppBackupImportSource/<n>-<set name>/…`. One fixed location, so an
    /// abandoned or crashed run's copy is always findable and removable.
    public nonisolated static var localSourceDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OldAppBackupImportSource", isDirectory: true)
    }

    /// Start a fresh import from a folder the user picked. The caller holds the security scope
    /// for the duration of this call; nothing outlives it, since everything the run needs is
    /// copied into the container before the first row is written.
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
            let sourceSets = LegacyBackup.BackupSet.discover(in: parentURL)
            guard !sourceSets.isEmpty else { throw ImportExportError.noBackupSetsFound }
            Log.info("OldAppBackupImporter: \(sourceSets.count) set(s) under \(parentURL.lastPathComponent): \(sourceSets.map(\.name).joined(separator: ", ")); cutoff \(cutoff.map { "\($0)" } ?? "none")", subsystem: .importing)

            let plan = copyPlan(for: sourceSets)
            guard !plan.jobs.isEmpty else { throw ImportExportError.noBackupSetsFound }
            try checkFreeSpace(copyBytes: plan.totalBytes, notLocalBytes: plan.notLocalBytes, sampleGzBytes: plan.sampleGzBytes)

            currentPhase = .copying
            try await copySets(plan)

            // from here on the picked folder is never touched again
            let sets = LegacyBackup.BackupSet.discover(in: localSourceDirectory)
            guard !sets.isEmpty else { throw ImportExportError.localCopyMissing }
            let weeks = weekPlan(for: sets)

            // the state row exists only once the copy is whole: a resume never has to ask iCloud
            // for anything, and a failed copy leaves nothing to resume
            let state = OldAppBackupImportState(sourceBookmark: Data(), totalWeekCount: weeks.count, cutoffDate: cutoff)
            try await OldAppBackupImportState.save(state)
            try await OldAppBackupImportState.recordAttemptStart()

            try await run(sets: sets, weeks: weeks, alreadyProcessed: [], cutoff: cutoff)

        } catch {
            Log.error("OldAppBackupImporter failed: \(error)", subsystem: .importing)
            if (try? await OldAppBackupImportState.current()) != nil {
                try? await OldAppBackupImportState.recordError(error)
            } else {
                // failed before the state row: nothing to resume, so nothing to keep
                removeLocalCopy()
            }
            endRun()
            throw error
        }
    }

    /// Resume an interrupted import from the local copy.
    public static func resumeImport() async throws {
        guard !importInProgress else { throw ImportExportError.importAlreadyInProgress }
        guard let state = try await OldAppBackupImportState.current() else {
            throw ImportExportError.importNotInitialised
        }

        await beginRun()
        do {
            currentPhase = .discovering
            let sets = LegacyBackup.BackupSet.discover(in: localSourceDirectory)
            guard !sets.isEmpty else {
                // the copy is gone (deleted from the Files app, or a row from before copy-first):
                // nothing can resume it. Drop the row so the app shows this as a start-again
                // alert, not a give-up cover whose Try Again can only fail the same way. What
                // already landed stays; a fresh start is insert-or-ignore over it.
                Log.error("OldAppBackupImporter: local copy missing on resume — clearing the import", subsystem: .importing)
                try? await OldAppBackupImportState.clear()
                throw ImportExportError.localCopyMissing
            }
            let weeks = weekPlan(for: sets)
            let remaining = weeks.filter { !state.processedWeekStems.contains($0.stem) }
            let gzBytes = remaining.flatMap(\.files).reduce(Int64(0)) { $0 + Int64((try? $1.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) }
            try checkFreeSpace(copyBytes: 0, notLocalBytes: 0, sampleGzBytes: gzBytes)
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

    /// Delete the local copy. Called by the app once its notes phase has read the copy, on
    /// Abandon, and at launch when no state row exists (a crash between the copy and the row).
    public static func removeLocalCopy() {
        let dir = localSourceDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        do {
            try FileManager.default.removeItem(at: dir)
            Log.info("OldAppBackupImporter: local copy removed", subsystem: .importing)
        } catch {
            Log.error("OldAppBackupImporter: could not remove local copy: \(error)", subsystem: .importing)
        }
    }

    /// A copy with no state row belongs to no import: remove it.
    public static func removeOrphanedLocalCopy() async {
        guard FileManager.default.fileExists(atPath: localSourceDirectory.path) else { return }
        guard !importInProgress else { return }
        if (try? await OldAppBackupImportState.current()) != nil { return }
        guard !importInProgress else { return }  // a start may have begun during the await
        removeLocalCopy()
    }

    // MARK: - Copying the sets local

    /// One file to copy: where it is (or would be, for an iCloud placeholder) and where it goes.
    struct CopyJob: Sendable {
        let source: URL       // the real name, whether or not the bytes are local yet
        let destination: URL
        let bytes: Int64      // real size, or the placeholder's declared size, or 0
    }

    struct CopyPlan: Sendable {
        var jobs: [CopyJob] = []
        var totalBytes: Int64 = 0
        var notLocalBytes: Int64 = 0   // still in iCloud: downloaded into iCloud's own cache before the copy
        var sampleGzBytes: Int64 = 0
    }

    /// The four record folders the run reads, in every set, with placeholders resolved to the
    /// names they stand for. `TimelineRangeSummary` is never read and never copied.
    static let copiedFolders = ["TimelineItem", "Place", "Note", "LocomotionSample"]

    private static func copyPlan(for sets: [LegacyBackup.BackupSet]) -> CopyPlan {
        var plan = CopyPlan()
        let fm = FileManager.default
        for (index, set) in sets.enumerated() {
            let destSet = localSourceDirectory.appendingPathComponent(String(format: "%02d-%@", index + 1, set.name), isDirectory: true)
            for folder in copiedFolders {
                let root = set.url.appendingPathComponent(folder, isDirectory: true)
                guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: []) else { continue }
                var planned = Set<String>()
                for case let fileURL as URL in enumerator {
                    guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                    guard let name = LegacyBackup.BackupSet.recordName(fromFilename: fileURL.lastPathComponent) else { continue }
                    let source = fileURL.deletingLastPathComponent().appendingPathComponent(name)
                    // a download mid-flight shows both the real file and its placeholder: one job
                    guard planned.insert(source.path).inserted else { continue }
                    let relative = source.path.replacingOccurrences(of: set.url.path + "/", with: "")
                    let isPlaceholder = fileURL.lastPathComponent != name
                    let bytes = fileSize(of: fileURL, placeholderFor: name)
                    plan.jobs.append(CopyJob(source: source, destination: destSet.appendingPathComponent(relative), bytes: bytes))
                    plan.totalBytes += bytes
                    if isPlaceholder { plan.notLocalBytes += bytes }
                    if folder == "LocomotionSample", name.hasSuffix(".json.gz") { plan.sampleGzBytes += bytes }
                }
            }
        }
        return plan
    }

    /// A local file's size, or the size an `.icloud` placeholder declares for the file it stands
    /// for (the placeholder is a plist carrying `NSURLFileSizeKey`). 0 when neither is readable;
    /// the free-space guard is then optimistic by that file, which the copy itself will catch.
    private static func fileSize(of fileURL: URL, placeholderFor name: String) -> Int64 {
        if fileURL.lastPathComponent == name {
            return Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let size = plist["NSURLFileSizeKey"] as? NSNumber else { return 0 }
        return size.int64Value
    }

    /// Copy every planned file into the container. A file already local is cloned by the file
    /// system; one that only exists as an iCloud placeholder is asked for and waited on (the
    /// `readCoordinated` path that Migrate's restore proved). Any file that never arrives fails
    /// the whole copy: better told up front than a half-imported timeline.
    private static func copySets(_ plan: CopyPlan) async throws {
        let fm = FileManager.default
        // a previous attempt's files are kept and skipped below (same name, same size), so a
        // retry after a failed download only fetches what is still missing
        try fm.createDirectory(at: localSourceDirectory, withIntermediateDirectories: true)

        // ask for everything not local before the walk, so downloads overlap the copying
        var notLocal = 0
        for job in plan.jobs where !fm.fileExists(atPath: job.source.path) {
            try? fm.startDownloadingUbiquitousItem(at: job.source)
            notLocal += 1
        }
        let total = plan.jobs.count
        Log.info("OldAppBackupImporter: copying \(total) files (\(plan.totalBytes / 1_048_576) MB), \(notLocal) not local yet", subsystem: .importing)
        currentWeekLabel = "0 of \(total.formatted()) files"

        var lastParent: URL?
        for (index, job) in plan.jobs.enumerated() {
            let parent = job.destination.deletingLastPathComponent()
            if parent != lastParent {
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                lastParent = parent
            }
            if let existing = (try? job.destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, job.bytes == 0 || Int64(existing) == job.bytes {
                // copied by an earlier attempt
            } else if fm.fileExists(atPath: job.source.path) {
                try? fm.removeItem(at: job.destination)
                try fm.copyItem(at: job.source, to: job.destination)
            } else {
                switch await iCloudCoordinator.readCoordinated(from: job.source, timeout: 60) {
                case .data(let data):
                    try data.write(to: job.destination)
                case .notLocalYet, .absent, .failed:
                    Log.error("OldAppBackupImporter: copy failed — \(job.source.lastPathComponent) never arrived from iCloud", subsystem: .importing)
                    throw ImportExportError.backupFilesNotDownloaded
                }
            }
            summary.filesCopied += 1
            summary.bytesCopied += job.bytes
            if index % 500 == 0 || index == total - 1 {
                currentWeekLabel = "\((index + 1).formatted()) of \(total.formatted()) files"
                progress = Double(index + 1) / Double(max(total, 1))
            }
        }
        Log.info("OldAppBackupImporter: copied \(summary.filesCopied) files (\(summary.bytesCopied / 1_048_576) MB)", subsystem: .importing)
        progress = 0
        currentWeekLabel = nil
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

    /// Refuse to start without room for the copy AND the import: the local copy is the sets'
    /// full size, a gzipped week expands roughly tenfold into JSON and lands in the database at
    /// roughly 1.5× its gzipped size, WAL included. Checked before the copy, so a full disk is a
    /// refusal, never a half-copied folder or a half-imported timeline.
    private static func checkFreeSpace(copyBytes: Int64, notLocalBytes: Int64, sampleGzBytes: Int64) throws {
        // files still in iCloud land in iCloud's cache first, then get copied: counted twice
        let needed = copyBytes + notLocalBytes + sampleGzBytes * 2 + 512 * 1024 * 1024
        if let available = Database.availableCapacity(at: Database.pool.path), available < needed {
            Log.error("OldAppBackupImporter: refusing to start — needs ~\(needed / 1_048_576) MB free (\(copyBytes / 1_048_576) MB to copy, of which \(notLocalBytes / 1_048_576) MB still in iCloud; \(sampleGzBytes / 1_048_576) MB of sample files to import), \(available / 1_048_576) MB available", subsystem: .importing)
            throw ImportExportError.insufficientFreeSpace
        }
    }

    private static func run(sets: [LegacyBackup.BackupSet], weeks: [WeekPlan], alreadyProcessed: Set<String>, cutoff: Date?) async throws {
        let startTime = Date()
        summary.sets = sets.count
        summary.weeksTotal = weeks.count
        summary.weeksProcessed = alreadyProcessed.count

        currentPhase = .importingWeeks
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

            try await importWeek(week, sets: sets, cutoff: cutoff)
            // preserved parents for this week's scenario-2 samples go in BEFORE the
            // checkpoint: after it, a kill would leave them parentless and the week "done"
            try await flushPreservedParents()
            try await OldAppBackupImportState.markWeekProcessed(week.stem)
            summary.weeksProcessed += 1
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

        // the local copy outlives the state row on purpose: the app's notes phase reads it next,
        // then removes it
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
    /// items its samples reference, then the samples. Every file is local (the copy phase saw
    /// to that); an unreadable copy is logged and skipped, since another set's may still serve.
    private static func importWeek(_ week: WeekPlan, sets: [LegacyBackup.BackupSet], cutoff: Date?) async throws {
        let decoder = LegacyBackup.decoder()

        // 1. read and union this week's samples across sets (newest lastSaved wins; nil never overwrites)
        var unioned: [String: LegacyBackup.Sample] = [:]
        for file in week.files {
            guard let gz = readFile(at: file.url) else { continue }
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
            let outcome = readUnioned(LegacyBackup.Item.self, id: itemId, in: sets, fileURL: { $0.itemFileURL(for: itemId) }, recordId: \.itemId, lastSaved: \.lastSaved)
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
                    let placeOutcome = readUnioned(LegacyBackup.Place.self, id: placeId, in: sets, fileURL: { $0.placeFileURL(for: placeId) }, recordId: \.placeId, lastSaved: \.lastSaved)
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
        // orphans are routine on this path (a set is a change-log; its item files often live in
        // another set), so the shared ERROR line for them would only shout
        SampleImportProcessor.logBatchResults(batchResult, orphansExpected: true)
        for (itemId, scenario2Samples) in batchResult.scenario2 {
            disabledSamplesFromEnabledParents[itemId, default: []] += scenario2Samples
        }

        Log.info("OldAppBackupImporter: \(stem) landed — \(samples.count) samples, \(itemsToInsert.count) items, \(placesToInsert.count) places, \(batchResult.orphanCount) orphans → \(counts.orphansRecreated + counts.orphansIndividual) items", subsystem: .importing)
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

    /// Read one record id from every set and union the copies. `nil` when no set has the file,
    /// or every copy is undecodable (skipped and logged), so the record counts as missing.
    private static func readUnioned<T: Decodable & Sendable>(
        _ type: T.Type, id: String, in sets: [LegacyBackup.BackupSet],
        fileURL: (LegacyBackup.BackupSet) -> URL, recordId: KeyPath<T, String>, lastSaved: KeyPath<T, Date?>
    ) -> T? {
        let decoder = LegacyBackup.decoder()
        var winner: T?
        for set in sets {
            let url = fileURL(set)
            guard let data = readFile(at: url, ifExists: true) else { continue }
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
        return winner
    }

    /// A local file's bytes, or nil. With `ifExists`, an absent file is the ordinary case (this
    /// set never held the record) and is silent; otherwise the file was planned and copied, so
    /// its absence or unreadability is an error worth a line.
    private static func readFile(at url: URL, ifExists: Bool = false) -> Data? {
        if ifExists, !FileManager.default.fileExists(atPath: url.path) { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            Log.error("OldAppBackupImporter: cannot read \(url.lastPathComponent): \(error)", subsystem: .importing)
            return nil
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
