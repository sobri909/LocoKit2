//
//  EdgeRecordManager.swift
//
//
//  Created on 2025-05-20.
//

import Foundation
import GRDB

/// Manages timeline item edge relationships during import operations
struct EdgeRecordManager {
    
    /// Record of a timeline item's edge relationships
    struct EdgeRecord: Codable {
        let itemId: String
        let previousId: String?
        let nextId: String?
    }
    
    /// URL for the temporary edge records file
    private let fileURL: URL
    
    /// Initialize with a temporary file URL
    init() {
        self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("edge_records_\(UUID().uuidString).jsonl")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Save an edge record to the temporary file
    func saveRecord(_ record: EdgeRecord) throws {
        if let data = try? JSONEncoder().encode(record) {
            try data.appendLine(to: fileURL)
        }
    }
    
    /// Restore edge relationships from the saved records
    @ImportExportActor
    func restoreEdgeRelationships(
        batchSize: Int = 200,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImportExportError.missingEdgeRecords
        }
        
        // Read edge records
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        
        var records: [EdgeRecord] = []
        
        // Read line by line to avoid memory pressure
        while let line = try fileHandle.readLine() {
            if let data = line.data(using: .utf8),
               let record = try? JSONDecoder().decode(EdgeRecord.self, from: data) {
                records.append(record)
            }
        }
        
        logger.info("Loaded \(records.count) edge records", subsystem: .database)
        
        // Process records in batches
        let batches = records.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try await Database.pool.write { db in
                for record in batch {
                    // check if the referenced items exist before setting edges
                    var validPreviousId = record.previousId
                    var validNextId = record.nextId
                    
                    if let previousId = record.previousId {
                        let previousExists = try TimelineItemBase
                            .filter(Column("id") == previousId)
                            .fetchCount(db) > 0
                        if !previousExists {
                            validPreviousId = nil
                        }
                    }
                    
                    if let nextId = record.nextId {
                        let nextExists = try TimelineItemBase
                            .filter(Column("id") == nextId)
                            .fetchCount(db) > 0
                        if !nextExists {
                            validNextId = nil
                        }
                    }
                    
                    try TimelineItemBase
                        .filter(Column("id") == record.itemId)
                        .updateAll(db, [
                            Column("previousItemId").set(to: validPreviousId),
                            Column("nextItemId").set(to: validNextId)
                        ])
                }
            }
            
            // Report progress
            if let progressHandler = progressHandler {
                let completedPercentage = Double(batchIndex + 1) / Double(batches.count)
                progressHandler(completedPercentage)
            }
            
            logger.info("Restored edge relationships batch \(batchIndex + 1)/\(batches.count)", subsystem: .database)
        }
    }
    
    /// Clean up the temporary file
    func cleanup() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
