//
//  iCloudCoordinator.swift
//  LocoKit2
//
//  Created by Claude on 2025-11-29
//

import Foundation

@ImportExportActor
public enum iCloudCoordinator {

    /// writes data to an iCloud-synced destination using NSFileCoordinator to prevent duplicates
    public static func writeCoordinated(data: Data, to destinationURL: URL) throws {
        let manager = FileManager.default

        // write to temp file first
        let tempURL = manager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try data.write(to: tempURL)

        defer { try? manager.removeItem(at: tempURL) }

        // use file coordinator for the replace
        var coordinatorError: NSError?
        var writeError: Error?

        NSFileCoordinator().coordinate(
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                if manager.fileExists(atPath: coordinatedURL.path) {
                    _ = try manager.replaceItemAt(
                        coordinatedURL,
                        withItemAt: tempURL,
                        backupItemName: nil,
                        options: .usingNewMetadataOnly
                    )

                } else {
                    try manager.moveItem(at: tempURL, to: coordinatedURL)
                }
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError { throw error }
        if let error = writeError { throw error }
    }

    /// outcome of a coordinated read — distinguishes genuine absence (first-run legitimate)
    /// from couldn't-read (which callers MUST treat non-destructively, never as "absent"). See BIG-597.
    public enum CoordinatedReadOutcome: Sendable {
        case data(Data)    // materialised and read
        case notLocalYet   // present in iCloud but couldn't be materialised in time (offline/timeout)
        case absent        // genuinely not present (not a ubiquitous item) — a true first run
        case failed        // read/coordination error (logged)
    }

    /// reads an iCloud-synced file, materialising it first if it's been evicted.
    ///
    /// The safety guarantee lives in the *outcome*, not in trusting iCloud's flaky sync state:
    /// only `.absent` (a genuine no-such-file that isn't a ubiquitous item) should ever drive
    /// destructive first-run behaviour. `.notLocalYet` / `.failed` mean "couldn't read" — callers
    /// must skip/abort, never re-export from scratch. See BIG-597.
    ///
    /// Run off the main thread (this can block on the coordinated read). Intended for `@ImportExportActor`.
    public static func readCoordinated(from url: URL, timeout: TimeInterval = 25) async -> CoordinatedReadOutcome {
        let manager = FileManager.default

        func downloadStatus() -> URLUbiquitousItemDownloadingStatus? {
            (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
        }

        // If it's a ubiquitous item that isn't local yet (evicted/stale), explicitly kick off the
        // download — insurance against the iOS 18.4+ "stuck stale / no auto-refresh" regression —
        // and bounded-poll for materialisation. Genuine absence falls straight through to the
        // coordinated read below (returns no-such-file fast), so a first run doesn't wait.
        let initialStatus = downloadStatus()
        if manager.isUbiquitousItem(at: url), initialStatus != .current, initialStatus != .downloaded {
            // not local (evicted / stale) — this is the path that matters on storage-constrained
            // devices. Log it so field logs prove the materialisation actually fired (BIG-597).
            let waitStart = Date()
            Log.info("readCoordinated: \(url.lastPathComponent) not local — materialising", subsystem: .exporting)
            try? manager.startDownloadingUbiquitousItem(at: url)
            let deadline = waitStart.addingTimeInterval(timeout)
            while Date() < deadline {
                let status = downloadStatus()
                if status == .current || status == .downloaded { break }
                try? await Task.sleep(for: .seconds(0.3))
            }
            // still not local after the wait (offline / slow sync) — bail non-destructively rather than
            // attempt a coordinated read that could block on a download that can't complete.
            let polledStatus = downloadStatus()
            if polledStatus != .current, polledStatus != .downloaded {
                Log.error("readCoordinated: \(url.lastPathComponent) not materialised after \(String(format: "%.1f", waitStart.age))s — giving up (non-destructive)", subsystem: .exporting)
                return .notLocalYet
            }
            Log.info("readCoordinated: \(url.lastPathComponent) materialised in \(String(format: "%.1f", waitStart.age))s", subsystem: .exporting)
        }

        var coordinatorError: NSError?
        var outcome: CoordinatedReadOutcome = .notLocalYet
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                outcome = .data(try Data(contentsOf: readURL))
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                // the only path to .absent — and only if it isn't a (possibly-evicted) ubiquitous item
                outcome = manager.isUbiquitousItem(at: url) ? .notLocalYet : .absent
            } catch {
                Log.error("readCoordinated read failed for \(url.lastPathComponent): \(error)", subsystem: .exporting)
                outcome = .failed
            }
        }
        if let coordinatorError {
            Log.error("readCoordinated coordination failed for \(url.lastPathComponent): \(coordinatorError)", subsystem: .exporting)
            return .failed
        }
        return outcome
    }

    /// logs the iCloud download status of all files in a directory (for debugging)
    public static func logDownloadStatus(in directory: URL, label: String) {
        let manager = FileManager.default

        guard let contents = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey]
        ) else {
            print("[\(label)] Could not read directory")
            return
        }

        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus

            let statusStr: String
            switch status {
            case .current: statusStr = "downloaded"
            case .downloaded: statusStr = "downloaded"
            case .notDownloaded: statusStr = "NOT downloaded"
            default: statusStr = "unknown"
            }

            print("[\(label)] \(url.lastPathComponent): \(statusStr)")
        }
    }

    /// purges iCloud conflict files (e.g., "A 2.json") which are always stale duplicates
    public static func purgeConflictFiles(in directory: URL) {
        let manager = FileManager.default

        guard let contents = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents {
            let name = url.deletingPathExtension().lastPathComponent

            // detect conflict patterns: trailing " N" or " (text)"
            let hasConflictSuffix = name.range(of: #" \d+$"#, options: .regularExpression) != nil
                || name.range(of: #" \([^)]+\)$"#, options: .regularExpression) != nil

            if hasConflictSuffix {
                Log.info("Purging iCloud conflict file: \(url.lastPathComponent)", subsystem: .exporting)

                var coordinatorError: NSError?
                NSFileCoordinator().coordinate(
                    writingItemAt: url,
                    options: .forDeleting,
                    error: &coordinatorError
                ) { coordinatedURL in
                    try? manager.removeItem(at: coordinatedURL)
                }
            }
        }
    }
}
