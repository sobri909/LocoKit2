//
//  LegacyBackup+BackupSet.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacyBackup {

    /// A backup set folder on disk and the paths inside it. No file is read here beyond
    /// directory listings; `.icloud` placeholders are recognised as members of the set.
    ///
    /// The old app never wrote a manifest or version marker, and the folder name carries only a
    /// random 8-hex suffix (`Backups`, `Previous Backups 5C941407`) — or whatever a user renamed
    /// it to. So a set is recognised by its contents: any folder holding at least one of the five
    /// record folders. A user's history is the UNION of every set they hold (a reinstall mints a
    /// new set without rewriting untouched records), which is why `discover(in:)` returns every
    /// set under a parent rather than the newest one.
    public struct BackupSet: Hashable, Sendable {

        public static let recordFolders = ["TimelineItem", "Place", "Note", "TimelineRangeSummary", "LocomotionSample"]

        public let url: URL
        public var name: String { url.lastPathComponent }

        public init?(url: URL) {
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let present = Self.recordFolders.filter { fm.fileExists(atPath: url.appendingPathComponent($0).path) }
            guard !present.isEmpty else { return nil }
            self.url = url
        }

        /// Every set at or under `parent`, two levels deep: the parent itself if it is a set,
        /// otherwise its subfolders, then theirs (a user's "ARC App in iCloud" copy holds
        /// `Backups`, `Previous Backups …` and hand-made folders side by side).
        public static func discover(in parent: URL) -> [BackupSet] {
            if let set = BackupSet(url: parent) { return [set] }
            let fm = FileManager.default
            var found: [BackupSet] = []
            func scan(_ dir: URL, depth: Int) {
                guard depth <= 2 else { return }
                guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
                for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    if let set = BackupSet(url: child) {
                        found.append(set)
                    } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        scan(child, depth: depth + 1)
                    }
                }
            }
            scan(parent, depth: 1)
            return found
        }

        // MARK: - Record paths

        /// Items bucket by the first two characters of the id, places and notes by the first one
        /// (`backupFolderPrefixLength`, unchanged since 2020).
        public func itemFileURL(for itemId: String) -> URL {
            url.appendingPathComponent("TimelineItem").appendingPathComponent(String(itemId.prefix(2))).appendingPathComponent(itemId + ".json")
        }

        public func placeFileURL(for placeId: String) -> URL {
            url.appendingPathComponent("Place").appendingPathComponent(String(placeId.prefix(1))).appendingPathComponent(placeId + ".json")
        }

        public func noteFileURL(for noteId: String) -> URL {
            url.appendingPathComponent("Note").appendingPathComponent(String(noteId.prefix(1))).appendingPathComponent(noteId + ".json")
        }

        /// Every record file under one of the record folders, `.icloud` placeholders resolved
        /// to the name they stand for. Ids are the filenames without `.json`.
        public func recordIds(in folder: String) -> [String] {
            let root = url.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: []) else { return [] }
            var ids: [String] = []
            for case let fileURL as URL in enumerator {
                guard let name = Self.recordName(fromFilename: fileURL.lastPathComponent), name.hasSuffix(".json") else { continue }
                ids.append(String(name.dropLast(5)))
            }
            return ids
        }

        /// The sample week files, sorted by filename (lexical == chronological for `YYYY-Www`).
        public func sampleWeekFiles() -> [SampleWeekFile] {
            let root = url.appendingPathComponent("LocomotionSample")
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return [] }
            var files: [SampleWeekFile] = []
            for filename in names {
                guard let name = Self.recordName(fromFilename: filename), name.hasSuffix(".json.gz") else { continue }
                files.append(SampleWeekFile(url: root.appendingPathComponent(name), stem: String(name.dropLast(8))))
            }
            return files.sorted { $0.stem < $1.stem }
        }

        /// `.<name>.icloud` → `<name>`; anything else unchanged. Skips `.DS_Store` and other dotfiles.
        static func recordName(fromFilename filename: String) -> String? {
            if filename.hasPrefix(".") {
                guard filename.hasSuffix(".icloud") else { return nil }
                return String(filename.dropFirst().dropLast(7))
            }
            return filename
        }
    }

    /// One `LocomotionSample/<stem>.json.gz`. The stem is normally an ISO week (`2021-W36`), but
    /// three pre-release forms exist for sets minted in October 2020 (`YYYY-ww`, `YYYY-MM-DD`);
    /// all three are accepted (BIG-399 decision 9). `weekStart` is nil for an unparseable stem,
    /// which the importer treats as a file to process, not to skip.
    public struct SampleWeekFile: Hashable, Sendable {
        public let url: URL
        public let stem: String

        public var isDownloaded: Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        public var weekStart: Date? {
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let parts = stem.split(separator: "-").map(String.init)
            guard parts.count >= 2, let year = Int(parts[0]) else { return nil }
            if parts.count == 2 {
                // "2021-W36" or the pre-release "2021-36"
                let weekString = parts[1].hasPrefix("W") ? String(parts[1].dropFirst()) : parts[1]
                guard let week = Int(weekString), (1...53).contains(week) else { return nil }
                return calendar.date(from: DateComponents(weekOfYear: week, yearForWeekOfYear: year))
            }
            if parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) {
                // pre-release per-day files
                return calendar.date(from: DateComponents(year: year, month: month, day: day))
            }
            return nil
        }
    }
}
