//
//  OrphanMappingsManager.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-06
//

import Foundation
import GRDB

public enum OrphanMappingsManager {

    struct PersistedMappings: Codable {
        var orphans: [String: [String]] = [:]      // originalItemId -> [sampleId]
        var scenario2: [String: [String]] = [:]    // originalItemId -> [sampleId] (disabled samples from enabled parents)
    }

    static func mappingsURL(for baseURL: URL) -> URL {
        baseURL.appendingPathComponent("orphan_mappings.json")
    }

    static func loadMappings(from baseURL: URL) -> PersistedMappings {
        let url = mappingsURL(for: baseURL)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let mappings = try? JSONDecoder().decode(PersistedMappings.self, from: data) else {
            return PersistedMappings()
        }
        return mappings
    }

    static func saveMappings(_ mappings: PersistedMappings, to baseURL: URL) {
        let url = mappingsURL(for: baseURL)
        do {
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: url)
        } catch {
            Log.error(error, subsystem: .importing)
        }
    }

    /// Append batch mappings to persistent file
    static func appendMappings(
        orphans: [String: [LocomotionSample]],
        scenario2: [String: [LocomotionSample]],
        to baseURL: URL
    ) {
        var mappings = loadMappings(from: baseURL)

        // append orphan sample IDs
        for (itemId, samples) in orphans {
            let sampleIds = samples.map { $0.id }
            mappings.orphans[itemId, default: []].append(contentsOf: sampleIds)
        }

        // append scenario2 sample IDs
        for (itemId, samples) in scenario2 {
            let sampleIds = samples.map { $0.id }
            mappings.scenario2[itemId, default: []].append(contentsOf: sampleIds)
        }

        saveMappings(mappings, to: baseURL)
    }

    /// Reconstruct orphanedSamples dictionary from persisted mappings by fetching samples from DB
    static func reconstructOrphans(from mappings: PersistedMappings) async throws -> (
        orphans: [String: [LocomotionSample]],
        scenario2: [String: [LocomotionSample]]
    ) {
        var orphans: [String: [LocomotionSample]] = [:]
        var scenario2: [String: [LocomotionSample]] = [:]

        // collect all sample IDs we need to fetch
        let allOrphanIds = Set(mappings.orphans.values.flatMap { $0 })
        let allScenario2Ids = Set(mappings.scenario2.values.flatMap { $0 })
        let allIds = allOrphanIds.union(allScenario2Ids)

        guard !allIds.isEmpty else { return (orphans, scenario2) }

        // fetch samples from DB
        let samples = try await Database.pool.read { db in
            try LocomotionSample
                .filter(allIds.contains(Column("id")))
                .fetchAll(db)
        }

        // build lookup by ID
        let sampleById = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })

        // reconstruct orphans dictionary
        for (itemId, sampleIds) in mappings.orphans {
            let itemSamples = sampleIds.compactMap { sampleById[$0] }
            if !itemSamples.isEmpty {
                orphans[itemId] = itemSamples
            }
        }

        // reconstruct scenario2 dictionary
        for (itemId, sampleIds) in mappings.scenario2 {
            let itemSamples = sampleIds.compactMap { sampleById[$0] }
            if !itemSamples.isEmpty {
                scenario2[itemId] = itemSamples
            }
        }

        return (orphans, scenario2)
    }
}
