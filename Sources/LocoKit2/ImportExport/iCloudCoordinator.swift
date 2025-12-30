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
