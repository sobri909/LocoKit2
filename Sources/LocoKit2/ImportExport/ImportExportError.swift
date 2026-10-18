//
//  ImportExportError.swift
//  LocoKit2
//
//  Created on 2025-05-22
//

import Foundation

public enum ImportExportError: Error {
    
    // MARK: - Export errors
    
    case exportInProgress
    case exportNotInitialised
    case manifestUnreadable          // manifest exists in iCloud but couldn't be materialised/read — skip this run, never first-run
    case manifestMissingButDataPresent  // no readable manifest, but the backup folder has data — abort rather than re-export from scratch

    // MARK: - General import errors
    
    case importInProgress
    case importNotInitialised
    case missingMetadata
    case missingPlacesDirectory
    case missingItemsDirectory
    case missingSamplesDirectory
    case invalidBookmark
    case securityScopeAccessDenied
    
    // MARK: - Legacy LocoKit import errors
    
    case importAlreadyInProgress
    case databaseConnectionFailed
    case missingLocoKitDatabase
    case missingArcAppDatabase

    // MARK: - Old app backup-set import errors (BIG-399)

    case noBackupSetsFound          // the picked folder holds no old-app backup set, at any depth searched
    case insufficientFreeSpace      // the free-space guard refused to start
    case backupFilesNotDownloaded   // iCloud placeholders stood in for files the run needed; retry once downloaded
    case localCopyMissing           // the container copy an import or resume reads is gone (BIG-399 copy-first)
    case invalidDatabaseSchema
    case importCancelled
    case placeImportFailed
    case timelineItemImportFailed
    case sampleImportFailed
    case noteImportFailed
    case validationFailed
    
    // MARK: - iCloud errors

    case iCloudNotAvailable
    case deviceIdentifierUnavailable

    // MARK: - Edge restoration errors
    
    case missingEdgeRecords

    // MARK: - Partial import blocking

    case partialImportInProgress
    case exportIdMismatch
}

// BIG-795: without this, `localizedDescription` is the NSError bridge's "The operation couldn't be
// completed. (LocoKit2.ImportExportError error 6.)", which the Import Incomplete cover and the
// restore/export alerts show to the user. One user-facing sentence per group of cases, from this
// package's own catalog (`bundle: .module`, as RecordingState and ActivityType do).
extension ImportExportError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .exportInProgress, .importInProgress, .importAlreadyInProgress, .partialImportInProgress:
            return String(localized: "Another import or export is already running.", bundle: .module)
        case .exportNotInitialised, .importNotInitialised:
            return String(localized: "The import couldn't be set up. Please try again.", bundle: .module)
        case .manifestUnreadable:
            return String(localized: "The backup's manifest couldn't be read.", bundle: .module)
        case .manifestMissingButDataPresent:
            return String(localized: "The backup folder has data but no manifest, so nothing was overwritten.", bundle: .module)
        case .missingMetadata:
            return String(localized: "The backup is missing its \(Self.part("metadata")).", bundle: .module)
        case .missingPlacesDirectory:
            return String(localized: "The backup is missing its \(Self.part("places")).", bundle: .module)
        case .missingItemsDirectory:
            return String(localized: "The backup is missing its \(Self.part("timeline items")).", bundle: .module)
        case .missingSamplesDirectory:
            return String(localized: "The backup is missing its \(Self.part("samples")).", bundle: .module)
        case .missingEdgeRecords:
            return String(localized: "The backup is missing its \(Self.part("timeline links")).", bundle: .module)
        case .invalidBookmark, .securityScopeAccessDenied:
            return String(localized: "Access to the backup folder was lost. Choose the folder again.", bundle: .module)
        case .databaseConnectionFailed, .missingLocoKitDatabase, .missingArcAppDatabase:
            return String(localized: "The old app's database couldn't be opened.", bundle: .module)
        case .noBackupSetsFound:
            return String(localized: "No Arc Timeline 3 backups were found in that folder.", bundle: .module)
        case .insufficientFreeSpace:
            return String(localized: "There isn't enough free space on this iPhone for the import.", bundle: .module)
        case .backupFilesNotDownloaded:
            return String(localized: "Some backup files are still in iCloud. Download them in the Files app, then try again.", bundle: .module)
        case .localCopyMissing:
            return String(localized: "The import's local copy of the backup is gone. Start the import again.", bundle: .module)
        case .invalidDatabaseSchema:
            return String(localized: "The backup's database isn't in a format this app can read.", bundle: .module)
        case .importCancelled:
            return String(localized: "The import was cancelled.", bundle: .module)
        case .placeImportFailed:
            return String(localized: "Importing the backup's \(Self.part("places")) failed.", bundle: .module)
        case .timelineItemImportFailed:
            return String(localized: "Importing the backup's \(Self.part("timeline items")) failed.", bundle: .module)
        case .sampleImportFailed:
            return String(localized: "Importing the backup's \(Self.part("samples")) failed.", bundle: .module)
        case .noteImportFailed:
            return String(localized: "Importing the backup's \(Self.part("notes")) failed.", bundle: .module)
        case .validationFailed:
            return String(localized: "The imported data didn't pass its checks.", bundle: .module)
        case .iCloudNotAvailable:
            return String(localized: "iCloud Drive isn't available on this iPhone.", bundle: .module)
        case .deviceIdentifierUnavailable:
            return String(localized: "This iPhone's identifier couldn't be read.", bundle: .module)
        case .exportIdMismatch:
            return String(localized: "This backup belongs to a different export.", bundle: .module)
        }
    }

    /// The noun slot of the two format sentences, translated on its own so each language orders
    /// the sentence as it likes
    private static func part(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

}