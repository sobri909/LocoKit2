//
//  OldAppBackupImporter.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation
import GRDB
import Synchronization

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

    public struct UnreadableWeek: Sendable {
        public let stem: String
        public let weekStart: Date?
    }

    /// What the last refused start needed and what was free, for the message the app shows.
    public struct SpaceShortfall: Sendable {
        public let neededBytes: Int64
        public let freeBytes: Int64
    }
    public private(set) static var lastSpaceShortfall: SpaceShortfall?

    /// Files found so far by a scan in flight. The scan is one synchronous walk that holds this
    /// actor for its whole length (minutes on a large corpus), so a cover polling for progress
    /// can't ask the actor; this is the one value it can read from outside.
    nonisolated private static let scanCounter = Mutex<Int>(0)
    nonisolated public static var scanFileCount: Int { scanCounter.withLock { $0 } }
    nonisolated public static func resetScanFileCount() { scanCounter.withLock { $0 = 0 } }

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
        public var samplesCollapsed = 0     // samples of item copies identical to a kept item's (decision 2)
        public var samplesUndecodable = 0
        public var sampleFilesUnreadable = 0   // a week file in the local copy that could not be read, unzipped or decoded
        /// Weeks for which NO set held a readable file: that week of history did not come across,
        /// and for a damaged file (won't unzip, isn't a sample array) never will from these sets.
        /// The run carries on past them (stopping would hold every later week hostage to a file
        /// nothing can fix) and the app says so at the end. Start-of-week dates, nil for a stem
        /// that isn't a date. This run only: a resumed run does not know an earlier attempt's.
        public var weeksUnreadable: [UnreadableWeek] = []
        public var itemsImported = 0
        public var itemsAlreadyPresent = 0
        public var itemsDeleted = 0
        public var itemsMissingFile = 0     // referenced by a sample, no file in any set → orphan path
        public var itemsUnreferenced = 0    // file exists, no sample references it → not imported
        public var itemsUnconvertible = 0
        public var itemsCollapsed = 0       // item copies whose samples equal another item's, point for point
        public var placesImported = 0
        public var placesAlreadyPresent = 0
        public var placesMissingFile = 0    // visit references a place no set holds → placeless visit
        public var placesUnconvertible = 0
        public var orphanSamples = 0
        public var orphanItemsRecreated = 0
        public var orphanIndividualItems = 0

        public var description: String {
            "\(sets) sets, \(filesCopied) files (\(bytesCopied / 1_048_576) MB) copied, \(weeksProcessed)/\(weeksTotal) weeks (\(weeksSkippedAfterCutoff) after cutoff); "
            + "samples \(samplesImported) imported, \(samplesAlreadyPresent) present, \(samplesAfterCutoff) after cutoff, \(samplesDeleted) deleted, \(samplesOfDeletedItems) of deleted items, \(samplesCollapsed) collapsed, \(samplesUndecodable) undecodable, \(sampleFilesUnreadable) week files unreadable, \(weeksUnreadable.count) weeks with no readable file; "
            + "items \(itemsImported) imported, \(itemsAlreadyPresent) present, \(itemsDeleted) deleted, \(itemsMissingFile) missing files, \(itemsUnreferenced) unreferenced, \(itemsCollapsed) collapsed, \(itemsUnconvertible) unconvertible; "
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
    /// item copies collapsed onto a kept item (decision 2); their samples are dropped in every
    /// week they appear in, so an item straddling a week boundary loses consistently
    private static var collapsedItemIds = Set<String>()

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

    /// What a picked folder holds, for the confirmation the app shows before anything starts
    /// (Day 167 decision 3: the conditions go in a tap-through, not grey footer text).
    public struct Scan: Sendable {
        public let setNames: [String]
        public let weekCount: Int
        public let fileCount: Int
        public let bytes: Int64          // everything that will be copied
        public let notLocalBytes: Int64  // of which still in iCloud
        public var sampleWeekSpan: (first: String, last: String)?
        // the walk's product, carried into `startImport` so the picked folder is walked once:
        // on a real iCloud Drive folder every listing is a round trip to the file provider
        let sets: [LegacyBackup.BackupSet]
        let plan: CopyPlan
    }

    /// Read-only look at a picked folder: the sets, their sample weeks, and the size of the
    /// copy the import would make. Throws `noBackupSetsFound` when there is nothing to import.
    /// The caller holds the security scope.
    public static func scan(_ parentURL: URL) throws -> Scan {
        let started = Date()
        Log.info("OldAppBackupImporter: scanning \(parentURL.lastPathComponent); memory \(memoryMB())", subsystem: .importing)
        scanCounter.withLock { $0 = 0 }
        let sets = LegacyBackup.BackupSet.discover(in: parentURL)
        guard !sets.isEmpty else { throw ImportExportError.noBackupSetsFound }
        Log.info("OldAppBackupImporter: \(sets.count) set(s) found, listing their files", subsystem: .importing)
        let plan = try copyPlan(for: sets)
        guard !plan.jobs.isEmpty else { throw ImportExportError.noBackupSetsFound }
        let weeks = weekPlan(for: sets)
        var scan = Scan(setNames: sets.map(\.name), weekCount: weeks.count, fileCount: plan.jobs.count, bytes: plan.totalBytes, notLocalBytes: plan.notLocalBytes, sets: sets, plan: plan)
        if let first = weeks.first?.stem, let last = weeks.last?.stem { scan.sampleWeekSpan = (first, last) }
        Log.info("OldAppBackupImporter: scanned \(sets.count) set(s): \(plan.jobs.count) files, \(mb(plan.totalBytes)) (\(mb(plan.notLocalBytes)) not local), \(weeks.count) weeks, in \(String(format: "%.1f", Date().timeIntervalSince(started))) s; memory \(memoryMB())", subsystem: .importing)
        return scan
    }

    /// Start a fresh import from a folder the user picked. The caller holds the security scope
    /// for the duration of this call; nothing outlives it, since everything the run needs is
    /// copied into the container before the first row is written.
    ///
    /// `before` is Migrate's parallel-era window: only records dated before it are imported, so
    /// a user who kept the old app recording beside AT4 doesn't get those days twice. Pass the
    /// earliest AT4-recorded date, or nil for a phone AT4 has never recorded on. Overlap-aware
    /// import is a different class of importer (the GPX / workout shape) and a separate ticket.
    public static func startImport(_ scan: Scan, before cutoff: Date?) async throws {
        guard !importInProgress else { throw ImportExportError.importAlreadyInProgress }

        await beginRun()
        do {
            currentPhase = .discovering
            let sourceSets = scan.sets
            Log.info("OldAppBackupImporter: \(sourceSets.count) set(s): \(sourceSets.map(\.name).joined(separator: ", ")); cutoff \(cutoff.map { "\($0)" } ?? "none")", subsystem: .importing)

            let plan = scan.plan
            try checkFreeSpace(copyBytes: plan.totalBytes, notLocalBytes: plan.notLocalBytes, sampleGzBytes: plan.uniqueSampleGzBytes)

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
            // the largest copy of each remaining week, as the fresh start sizes it: summing every
            // set's copy would refuse a resume of a run the start had allowed
            let gzBytes = remaining.reduce(Int64(0)) { total, week in
                total + (week.files.map { Int64((try? $0.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) }.max() ?? 0)
            }
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

    /// One file to copy: its directory (in `CopyPlan.dirs`) and its real name, whether or not
    /// the bytes are local yet. Deliberately small: a job that held its two URLs cost ~3 KB in
    /// the app, and a 567,099-file corpus held 1.7 GB for the whole run (1.3 GB on a 13 Pro).
    struct CopyJob: Sendable {
        let dir: Int32
        let name: String
        let bytes: Int64      // real size, or the placeholder's declared size, or 0
        let notLocal: Bool    // still in iCloud: asked for and waited on rather than cloned
    }

    /// A directory in a picked set and where its files go in the local copy.
    struct CopyDir: Sendable {
        let source: URL
        let destination: URL
    }

    struct CopyPlan: Sendable {
        var dirs: [CopyDir] = []
        var jobs: [CopyJob] = []
        func source(of job: CopyJob) -> URL { dirs[Int(job.dir)].source.appendingPathComponent(job.name) }
        func destination(of job: CopyJob) -> URL { dirs[Int(job.dir)].destination.appendingPathComponent(job.name) }
        var totalBytes: Int64 = 0
        var notLocalBytes: Int64 = 0   // still in iCloud: downloaded into iCloud's own cache before the copy
        var sampleGzBytes: Int64 = 0
        /// The largest copy of each sample week across the sets. Sets overlap heavily (a restore
        /// rewrites weeks an older set already holds) and the import keeps one copy of each
        /// sample, so this, not the sum, is what the database will grow by.
        var largestGzByWeek: [String: Int64] = [:]
        var uniqueSampleGzBytes: Int64 { largestGzByWeek.values.reduce(0, +) }
    }

    /// The four record folders the run reads, in every set, with placeholders resolved to the
    /// names they stand for. `TimelineRangeSummary` is never read and never copied.
    static let copiedFolders = ["TimelineItem", "Place", "Note", "LocomotionSample"]

    /// The walk is one directory listing per folder, with every value it needs prefetched by
    /// that listing. On a real iCloud Drive folder each listing is a round trip to the file
    /// provider, and the record folders are shallow shards (`TimelineItem/<2 hex>/<id>.json`),
    /// so this is a few hundred calls per set; a deep enumerator asking each file for its
    /// values one at a time was tens of thousands, and took minutes on a phone (Day 168).
    private static let planKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey]
    /// For a set that is not in iCloud (a copy under On My iPhone, say). The download-status key
    /// is a provider question per file and costs ~20× the listing itself (10,937 files: 0.85 s
    /// with it, 0.04 s without, measured on a Mac), which on a 576,000-file corpus is the
    /// difference between a scan and a long wait. In the app the gap is wider: 12.0 s against
    /// 0.4 s for 10,285 files in the simulator.
    private static let localPlanKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]

    private static func copyPlan(for sets: [LegacyBackup.BackupSet]) throws -> CopyPlan {
        var plan = CopyPlan()
        let fm = FileManager.default
        for (index, set) in sets.enumerated() {
            let destSet = localSourceDirectory.appendingPathComponent(String(format: "%02d-%@", index + 1, set.name), isDirectory: true)
            // Only a set that is in iCloud is asked for per-file download status. The set's own
            // folder answers that: outside iCloud it has neither the ubiquitous flag nor a
            // download status (both nil in the simulator and under On My iPhone). A wrong
            // "local" here is survivable: a clone that fails joins the download queue.
            let rootValues = try? set.url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
            let inICloud = rootValues?.isUbiquitousItem == true || rootValues?.ubiquitousItemDownloadingStatus != nil
            let keys = inICloud ? planKeys : localPlanKeys
            for folder in copiedFolders {
                let root = set.url.appendingPathComponent(folder, isDirectory: true)
                // a set without this record folder is normal (no notes, say); a listing that fails
                // anywhere below it is not, and the files it would have held must not just vanish
                // from the plan (a backup import fails loud, never half)
                guard fm.fileExists(atPath: root.path) else { continue }
                // (directory, its path under the set) so destinations come from components, never
                // from string surgery on paths the provider may return with a resolved prefix
                var pending: [(dir: URL, relative: [String])] = [(root, [folder])]
                while let (dir, relative) = pending.popLast() {
                    // a large corpus is minutes of listings; the scan cover's Cancel ends it here
                    if Task.isCancelled { throw CancellationError() }
                    var destination = destSet
                    for component in relative { destination.appendPathComponent(component, isDirectory: true) }
                    let dirIndex = Int32(plan.dirs.count)
                    plan.dirs.append(CopyDir(source: dir, destination: destination))
                    // the listing's URLs are autoreleased; without a pool per directory half a
                    // million of them pile up until the walk returns
                    try autoreleasepool {
                        // not `.skipsHiddenFiles`: a macOS / simulator placeholder is a `.name.icloud` dotfile
                        let children: [URL]
                        do { children = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: Array(keys), options: []) }
                        catch {
                            Log.error("OldAppBackupImporter: couldn't list \(set.name)/\(relative.joined(separator: "/")): \(error)", subsystem: .importing)
                            throw ImportExportError.backupFilesNotDownloaded
                        }
                        var planned = Set<String>()
                        for fileURL in children {
                            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
                            let filename = fileURL.lastPathComponent
                            if values.isDirectory == true { pending.append((fileURL, relative + [filename])); continue }
                            guard values.isRegularFile == true else { continue }
                            guard let name = LegacyBackup.BackupSet.recordName(fromFilename: filename) else { continue }
                            // a download mid-flight shows both the real file and its placeholder: one job
                            guard planned.insert(name).inserted else { continue }
                            // a Mac / simulator placeholder is the dotfile; an iOS one is the real name
                            // with the provider saying the bytes aren't here
                            let isDotfilePlaceholder = filename != name
                            let notLocal = isDotfilePlaceholder || values.ubiquitousItemDownloadingStatus == .notDownloaded
                            let bytes = isDotfilePlaceholder ? placeholderDeclaredSize(fileURL) : Int64(values.fileSize ?? 0)
                            plan.jobs.append(CopyJob(dir: dirIndex, name: name, bytes: bytes, notLocal: notLocal))
                            plan.totalBytes += bytes
                            if notLocal { plan.notLocalBytes += bytes }
                            if folder == "LocomotionSample", name.hasSuffix(".json.gz") {
                                plan.sampleGzBytes += bytes
                                plan.largestGzByWeek[name] = max(plan.largestGzByWeek[name] ?? 0, bytes)
                            }
                        }
                    }
                    let found = plan.jobs.count
                    scanCounter.withLock { $0 = found }
                }
            }
            // one line per set: a walk of hundreds of thousands of files is otherwise silent
            // between its first log line and its last
            Log.info("OldAppBackupImporter: listed \(set.name) (\(index + 1) of \(sets.count), \(inICloud ? "iCloud" : "local")), \(plan.jobs.count) files so far", subsystem: .importing)
        }
        return plan
    }

    /// The app's memory footprint in MB (the figure Xcode's gauge and jetsam use), for the log.
    /// A multi-set union on a real phone sat at 1.3 GB where a single set sat at 150 MB, and
    /// nothing in the log said which step it arrived at.
    nonisolated private static func memoryMB() -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return "? MB" }
        return "\(info.phys_footprint / 1_048_576) MB"
    }

    /// Log sizes: whole MB, or KB below one, so a few thousand tiny record files never read as "0 MB".
    private static func mb(_ bytes: Int64) -> String {
        bytes >= 1_048_576 ? "\(bytes / 1_048_576) MB" : "\(bytes / 1024) KB"
    }

    /// The size a `.icloud` placeholder declares for the file it stands for (the placeholder is
    /// a plist carrying `NSURLFileSizeKey`). 0 when unreadable; the free-space guard is then
    /// optimistic by that file, which the copy itself will catch.
    private static func placeholderDeclaredSize(_ fileURL: URL) -> Int64 {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let size = plist["NSURLFileSizeKey"] as? NSNumber else { return 0 }
        return size.int64Value
    }

    /// Copy every planned file into the container. A file already local is cloned by the file
    /// system in plan order. The rest are asked for in bulk and then taken in whatever order
    /// iCloud delivers them: a per-file timeout measures nothing about a queue of thousands the
    /// daemon works through in its own order (Day 168: the first file waited 60 s and failed the
    /// run while the queue was being served). What fails the copy is a stall, nothing landing
    /// for `stallTimeout`; better told up front than a half-imported timeline.
    static let stallTimeout: TimeInterval = 90

    private static func copySets(_ plan: CopyPlan) async throws {
        let fm = FileManager.default
        // a failed start removes its copy (nothing to resume without a state row), so a retry
        // copies everything again; what a retry does reuse is iCloud's own cache of the files
        // the first attempt downloaded, which is where the time went
        try fm.createDirectory(at: localSourceDirectory, withIntermediateDirectories: true)

        // ask for everything not local before the walk, so downloads overlap the cloning
        var notLocal = 0
        for job in plan.jobs where job.notLocal {
            try? fm.startDownloadingUbiquitousItem(at: plan.source(of: job))
            notLocal += 1
        }
        let total = plan.jobs.count
        Log.info("OldAppBackupImporter: copying \(total) files (\(mb(plan.totalBytes))), \(notLocal) not local yet (\(mb(plan.notLocalBytes)))", subsystem: .importing)
        currentWeekLabel = "0 of \(total.formatted()) files"

        func copied(_ job: CopyJob) {
            summary.filesCopied += 1
            summary.bytesCopied += job.bytes
            if summary.filesCopied % 200 == 0 || summary.filesCopied == total {
                currentWeekLabel = "\(summary.filesCopied.formatted()) of \(total.formatted()) files"
                progress = Double(summary.filesCopied) / Double(max(total, 1))
            }
        }

        // pass one: clone what is local, in plan order (one directory create per parent)
        var waiting: [CopyJob] = []
        var lastDir: Int32 = -1
        for job in plan.jobs {
            if job.dir != lastDir {
                try fm.createDirectory(at: plan.dirs[Int(job.dir)].destination, withIntermediateDirectories: true)
                lastDir = job.dir
            }
            let source = plan.source(of: job), destination = plan.destination(of: job)
            try? fm.removeItem(at: destination)
            if job.notLocal { waiting.append(job); continue }
            // a file the plan called local but that iCloud has since evicted (or whose status the
            // provider never reported) joins the download queue instead of failing the run, so a
            // wrong local / not-local call is harmless either way
            do {
                try fm.copyItem(at: source, to: destination)
                copied(job)
                // this loop holds the actor; without a suspension the cover's poll of the count
                // never gets in, and half a million local files sit at 0% for six minutes
                if summary.filesCopied % 200 == 0 { await Task.yield() }
            }
            catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
                // a full disk is not an iCloud wait; say so instead of stalling for 90 s
                Log.error("OldAppBackupImporter: out of space copying \(job.name) after \(summary.filesCopied) of \(total) files", subsystem: .importing)
                throw ImportExportError.insufficientFreeSpace
            }
            catch {
                Log.info("OldAppBackupImporter: clone of \(job.name) failed (\(error.localizedDescription)); waiting for it from iCloud instead", subsystem: .importing)
                try? fm.startDownloadingUbiquitousItem(at: source)
                waiting.append(job)
            }
        }

        // pass two: take the rest as they land, in iCloud's order, until nothing lands any more
        var lastLanded = Date()
        var lastKick = Date()
        var sweeps = 0
        while !waiting.isEmpty {
            sweeps += 1
            var stillWaiting: [CopyJob] = []
            var landed = 0
            for job in waiting {
                let source = plan.source(of: job)
                let status = (try? source.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
                guard status == .current || status == .downloaded else { stillWaiting.append(job); continue }
                switch await iCloudCoordinator.readCoordinated(from: source, timeout: 5) {
                case .data(let data):
                    do { try data.write(to: plan.destination(of: job)) }
                    catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
                        Log.error("OldAppBackupImporter: out of space writing \(job.name) after \(summary.filesCopied) of \(total) files", subsystem: .importing)
                        throw ImportExportError.insufficientFreeSpace
                    }
                    copied(job)
                    landed += 1
                case .notLocalYet, .absent, .failed:
                    stillWaiting.append(job)   // the status said local; the read disagreed; ask again next sweep
                }
            }
            waiting = stillWaiting
            if landed > 0 { lastLanded = Date() }
            if sweeps == 1 || sweeps % 10 == 0 || waiting.isEmpty {
                Log.info("OldAppBackupImporter: sweep \(sweeps): \(landed) landed, \(waiting.count) still in iCloud, \(String(format: "%.0f", Date().timeIntervalSince(lastLanded))) s since the last arrival", subsystem: .importing)
            }
            guard !waiting.isEmpty else { break }
            let sinceLanded = Date().timeIntervalSince(lastLanded)
            if sinceLanded > stallTimeout {
                Log.error("OldAppBackupImporter: copy stalled — nothing arrived from iCloud in \(String(format: "%.0f", sinceLanded)) s, \(waiting.count) of \(total) files still not local (first: \(waiting[0].name))", subsystem: .importing)
                throw ImportExportError.backupFilesNotDownloaded
            }
            // the daemon can drop a request it never got to; ask again for the stragglers now and then
            if Date().timeIntervalSince(lastKick) > 30 {
                for job in waiting { try? fm.startDownloadingUbiquitousItem(at: plan.source(of: job)) }
                lastKick = Date()
            }
            try? await Task.sleep(for: .seconds(1))
        }
        // free space after the copy, against the figure logged before it: on one volume the copy is
        // a clone and should cost almost nothing, which is what the space estimate has to learn
        let freeAfter = (try? URL(fileURLWithPath: Database.pool.path).resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity
        Log.info("OldAppBackupImporter: copied \(summary.filesCopied) files (\(mb(summary.bytesCopied))); \(freeAfter.map { "\($0 / 1_048_576)" } ?? "?") MB free now; memory \(memoryMB())", subsystem: .importing)
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
        lastSpaceShortfall = nil   // an earlier refusal's figures must not caption a later failure
        // The strict figure, on purpose. iOS Settings (and the "important usage" capacity) count
        // space iOS could purge, and in practice it does not purge on demand: a phone showing
        // ~70 GB spare had 11.9 GB free, and writes fail against the smaller number (BIG-745).
        // The refusal carries both numbers so the user can be told why Settings disagrees.
        let url = URL(fileURLWithPath: Database.pool.path)
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let freeNow = values?.volumeAvailableCapacity.map(Int64.init)
        let withPurgeable = values?.volumeAvailableCapacityForImportantUsage
        Log.info("OldAppBackupImporter: needs ~\(needed / 1_048_576) MB free (\(copyBytes / 1_048_576) MB to copy, of which \(notLocalBytes / 1_048_576) MB still in iCloud; \(sampleGzBytes / 1_048_576) MB of sample weeks to import); \(freeNow.map { "\($0 / 1_048_576)" } ?? "?") MB free now, \(withPurgeable.map { "\($0 / 1_048_576)" } ?? "?") MB counting purgeable", subsystem: .importing)
        if let freeNow, freeNow < needed {
            lastSpaceShortfall = SpaceShortfall(neededBytes: needed, freeBytes: freeNow)
            Log.error("OldAppBackupImporter: refusing to start — not enough free space", subsystem: .importing)
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
            if index % 25 == 0 { Log.info("OldAppBackupImporter: at \(week.stem) (\(index + 1) of \(weeks.count)); memory \(memoryMB())", subsystem: .importing) }

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
        Log.info("OldAppBackupImporter completed in \(minutes) min; memory \(memoryMB()): \(summary.description)", subsystem: .importing)
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
        var readableFiles = 0
        for file in week.files {
            guard let gz = readFile(at: file.url) else { summary.sampleFilesUnreadable += 1; continue }
            let json: Data
            do { json = try gz.gzipDecompressed() } catch {
                Log.error("OldAppBackupImporter: \(file.url.lastPathComponent) failed to decompress: \(error)", subsystem: .importing)
                summary.sampleFilesUnreadable += 1
                continue
            }
            let elements: [LegacyBackup.Lenient<LegacyBackup.Sample>]
            do { elements = try decoder.decode([LegacyBackup.Lenient<LegacyBackup.Sample>].self, from: json) } catch {
                Log.error("OldAppBackupImporter: \(file.url.lastPathComponent) is not a sample array: \(error)", subsystem: .importing)
                summary.sampleFilesUnreadable += 1
                continue
            }
            // a file that parses but in which no sample decodes is as lost as one that won't unzip
            if elements.isEmpty || elements.contains(where: { $0.value != nil }) {
                readableFiles += 1
            } else {
                Log.error("OldAppBackupImporter: \(file.url.lastPathComponent) holds \(elements.count) samples and none decode", subsystem: .importing)
                summary.sampleFilesUnreadable += 1
            }
            for element in elements {
                guard let sample = element.value else { summary.samplesUndecodable += 1; continue }
                if let cutoff, sample.date >= cutoff { summary.samplesAfterCutoff += 1; continue }
                merge(sample, into: &unioned, id: sample.sampleId, lastSaved: sample.lastSaved)
            }
        }

        if !week.files.isEmpty, readableFiles == 0 {
            Log.error("OldAppBackupImporter: \(week.stem) has no readable sample file in any set (\(week.files.count) tried); the week is not imported", subsystem: .importing)
            summary.weeksUnreadable.append(UnreadableWeek(stem: week.stem, weekStart: week.files.first?.weekStart))
        }

        // 1b. exact duplicates (decision 2): the old app's Moves import ran more than once for
        //     some users, minting the same journeys under new ids. Item copies whose samples are
        //     identical in every recorded field except their ids are one item; keep one.
        var liveSamples = unioned.values.filter { !$0.isDeleted }
        summary.samplesDeleted += unioned.count - liveSamples.count
        let losers = collapseDuplicateItems(among: liveSamples, sets: sets)
        if !losers.isEmpty {
            collapsedItemIds.formUnion(losers)
            handledItemIds.formUnion(losers)  // never read, never counted unreferenced
            summary.itemsCollapsed += losers.count
        }
        if !collapsedItemIds.isEmpty {
            let before = liveSamples.count
            liveSamples.removeAll { $0.timelineItemId.map(collapsedItemIds.contains) ?? false }
            summary.samplesCollapsed += before - liveSamples.count
        }

        // 2. the items the LIVE samples reference, and the places those items reference. An
        //    item referenced only by deleted samples would land as a dateless shell (dates in
        //    LocoKit2 derive from samples), which is the class decision 1 exists to exclude.
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

    // MARK: - Exact-duplicate items (decision 2)

    /// A sample with its identity stripped: every recorded field except `sampleId`,
    /// `timelineItemId` and `lastSaved`, and except `secondsFromGMT`, which is the importing
    /// phone's time zone at the moment the old app minted the sample, not a property of the
    /// point (Tristan's three Moves imports stamped the same points -18000, -21600 and nil;
    /// everything else, `lastSaved` included, was identical). Two samples with equal
    /// signatures are the same recording, whatever ids the old app gave them.
    private struct SampleSignature: Hashable {
        let date: Date
        let location: LegacyBackup.Sample.Location?
        let movingState: String
        let recordingState: String
        let stepHz: Double?
        let courseVariance: Double?
        let xyAcceleration: Double?
        let zAcceleration: Double?
        let confirmedType: String?
        let classifiedType: String?
        let disabled: Bool?

        init(_ s: LegacyBackup.Sample) {
            date = s.date; location = s.location
            movingState = s.movingState; recordingState = s.recordingState
            stepHz = s.stepHz; courseVariance = s.courseVariance
            xyAcceleration = s.xyAcceleration; zAcceleration = s.zAcceleration
            confirmedType = s.confirmedType; classifiedType = s.classifiedType; disabled = s.disabled
        }
    }

    /// Item ids whose samples (in this week) equal another item's point for point. Of each
    /// group of identical items the one with the newest item-file `lastSaved` is kept; a tie,
    /// or no item file at all, keeps the smallest id, which is the same answer in every week
    /// the group appears in. Items already collapsed in an earlier week are not regrouped.
    private static func collapseDuplicateItems(among samples: [LegacyBackup.Sample], sets: [LegacyBackup.BackupSet]) -> Set<String> {
        var byItem: [String: [SampleSignature]] = [:]
        for sample in samples {
            guard let itemId = sample.timelineItemId, !collapsedItemIds.contains(itemId) else { continue }
            byItem[itemId, default: []].append(SampleSignature(sample))
        }
        var groups: [[SampleSignature]: [String]] = [:]
        for (itemId, signatures) in byItem {
            let ordered = signatures.sorted { $0.date < $1.date }
            groups[ordered, default: []].append(itemId)
        }
        var losers = Set<String>()
        var groupsByCopyCount: [Int: Int] = [:]
        for (signatures, itemIds) in groups where itemIds.count > 1 {
            var saved: [String: Date?] = [:]
            for itemId in itemIds {
                let record = readUnioned(LegacyBackup.Item.self, id: itemId, in: sets, fileURL: { $0.itemFileURL(for: itemId) }, recordId: \.itemId, lastSaved: \.lastSaved)
                saved[itemId] = record?.lastSaved
            }
            let winner = itemIds.sorted { a, b in
                switch (saved[a] ?? nil, saved[b] ?? nil) {
                case (.some(let x), .some(let y)) where x != y: return x > y
                case (.some, .none): return true
                case (.none, .some): return false
                default: return a < b
                }
            }.first!
            for itemId in itemIds where itemId != winner { losers.insert(itemId) }
            groupsByCopyCount[itemIds.count, default: 0] += 1
            // per group to the console only: a Moves-era decade is thousands of these, and in the
            // log file they would bury the lines a support case needs
            Log.debug("OldAppBackupImporter: \(itemIds.count) identical item copies (\(signatures.count) samples each) — keeping \(winner)", subsystem: .importing)
        }
        if !losers.isEmpty {
            let shape = groupsByCopyCount.keys.sorted().map { "\(groupsByCopyCount[$0]!) item(s) × \($0) copies" }.joined(separator: ", ")
            Log.info("OldAppBackupImporter: collapsed \(losers.count) duplicate item copies this week (\(shape))", subsystem: .importing)
        }
        return losers
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
        collapsedItemIds = []
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
