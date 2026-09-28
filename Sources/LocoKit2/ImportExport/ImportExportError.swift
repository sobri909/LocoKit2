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