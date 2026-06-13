//
//  ImportExportActivity.swift
//  LocoKit2
//
//  Created by Claude on 2026-06-13
//

import Foundation

@ImportExportActor
public enum ImportExportActivity {

    /// True while any heavy import/export DB operation is in flight — either an active
    /// in-memory operation, or persisted incomplete/partial state from an interrupted one
    /// (the latter covers the window between launch and auto-resume, before the in-memory
    /// flag is set). Framework-visible equivalent of the app's `Session.doingHeavyDatabaseWork`,
    /// migrations excepted (those are app-orchestrated; see BIG-440 / BIG-602).
    ///
    /// Background tasks defer while this is true, to avoid running over half-shaped data (BIG-600).
    public static var inProgress: Bool {
        get async {
            if OldLocoKitImporter.importInProgress { return true }
            if ImportManager.importInProgress { return true }
            if ExportManager.exportInProgress { return true }
            if await ImportState.hasPartialImport { return true }
            if await OldLocoKitImportState.hasIncompleteImport { return true }
            return false
        }
    }
}
