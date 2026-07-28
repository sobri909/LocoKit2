//
//  Place+Merge.swift
//  LocoKit2
//
//  Created by Claude on 2026-07-28.
//

import Foundation
import GRDB

extension Place {

    /// Reassigns every visit from `deadman` to this place, then deletes `deadman`.
    ///
    /// `timelineItemVisit.placeId` is a deferred FK, so the reassignment and the delete are both
    /// safe inside the one transaction. `confirmedPlace` / `uncertainPlace` are left untouched:
    /// each visit keeps its own manual-vs-auto status, and the CHECK constraints hold because
    /// placeId stays non-nil throughout. The deadman's DriftProfile cascades away with it, and
    /// its rtree row goes by trigger.
    ///
    /// `StoredSettings.calendarSyncPlaceIds` lives outside the FK graph, so migrating it is the
    /// caller's responsibility — calendar sync silently dies for these visits otherwise.
    @PlacesActor
    public func absorb(_ deadman: Place) async throws {
        guard deadman.id != id else { return }

        let movedCount = try await Database.pool.write { [keeperId = id, deadmanId = deadman.id] db in
            let moved = try TimelineItemVisit
                .filter { $0.placeId == deadmanId }
                .updateAll(db) { [$0.placeId.set(to: keeperId)] }
            try Place.filter(id: keeperId).updateAll(db) { [$0.isStale.set(to: true)] }
            try Place.deleteOne(db, id: deadmanId)
            return moved
        }

        Log.info("ABSORBED: \(deadman.name) into \(name), \(movedCount) visits moved", subsystem: .places)

        // recompute from a freshly fetched copy. updateVisitStats() clears isStale via
        // updateChanges(), which diffs against its own in-memory snapshot — so recomputing on a
        // copy that still reads isStale == false would silently skip clearing the flag set above
        let keeper = try await Database.pool.read { [keeperId = id] db in try Place.fetchOne(db, id: keeperId) }
        await keeper?.updateVisitStats()
    }

    /// Merge candidates: places whose footprint overlaps this one's, nearest first.
    ///
    /// PlaceRTree indexes place centres as degenerate points (latMin == latMax == latitude), so it
    /// carries no radius and the query can only collect a coarse candidate set — `overlaps()` does
    /// the real filtering in memory afterwards. The box pads by this place's own reach plus
    /// `maximumPlaceRadius`, covering any candidate with a sane radiusSD. A place scattered enough
    /// to have an extreme SD isn't a sensible merge candidate anyway.
    public func overlappingPlaces(minimumVisits: Int = 1) async throws -> [Place] {
        let metresPerDegree = 111_319.9
        let reach = radius.with3sd + Place.maximumPlaceRadius
        let latPad = reach / metresPerDegree
        let lonPad = reach / (metresPerDegree * max(cos(latitude.radians), 0.01))

        let candidates = try await Database.pool.read { [id, latitude, longitude, minimumVisits] db in
            try Place
                .joining(required: Place.rtree.aliased(TableAlias(name: "r")))
                .filter(
                    sql: """
                        r.latMin >= :latMin AND r.latMax <= :latMax AND
                        r.lonMin >= :lonMin AND r.lonMax <= :lonMax
                        """,
                    arguments: [
                        "latMin": latitude - latPad, "latMax": latitude + latPad,
                        "lonMin": longitude - lonPad, "lonMax": longitude + lonPad
                    ]
                )
                .filter { $0.id != id && $0.visitCount >= minimumVisits }
                .fetchAll(db)
        }

        return candidates
            .filter { overlaps($0) }
            .sorted { center.location.distance(from: $0.center.location) < center.location.distance(from: $1.center.location) }
    }

}
