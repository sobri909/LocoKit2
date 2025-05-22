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
    case invalidDatabaseSchema
    case importCancelled
    case placeImportFailed
    case timelineItemImportFailed
    case sampleImportFailed
    case noteImportFailed
    case validationFailed
    
    // MARK: - iCloud errors
    
    case iCloudNotAvailable
    
    // MARK: - Edge restoration errors
    
    case missingEdgeRecords
}