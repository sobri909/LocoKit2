//
//  DriftProfile+Learning.swift
//  Arc Timeline
//
//  Created by Claude on 2026-04-15
//

import Foundation
import CoreLocation
import GRDB

extension DriftProfile {

    // MARK: - Profile Computation

    public static func computeProfile(for samples: [LocomotionSample], place: Place) -> DriftProfile? {
        let placeCentroid = CLLocation(latitude: place.latitude, longitude: place.longitude)

        // filter to samples with usable locations
        let locatableSamples = samples.filter { $0.location != nil }
        guard !locatableSamples.isEmpty else { return nil }

        // compute distances from centroid — beyond the place's normal footprint
        let threshold = max(place.radius.with1sd, 30.0)
        let excursionSamples = locatableSamples.filter { sample in
            sample.location!.distance(from: placeCentroid) > threshold
        }

        // need 3+ excursion samples to be meaningful
        guard excursionSamples.count >= 3 else {
            if !excursionSamples.isEmpty {
                Log.info("DriftProfile skipped '\(place.name)': only \(excursionSamples.count) excursion samples (need 3+)", subsystem: .misc)
            }
            return nil
        }

        // compute per-excursion-sample metrics
        var distances: [Double] = []
        var sectorCounts = Array(repeating: 0, count: 8)
        var sectorDistanceSums = Array(repeating: 0.0, count: 8)
        var validSpeeds: [Double] = []
        var hAccValues: [Double] = []
        var vAccValues: [Double] = []
        var courseValidCount = 0

        for sample in excursionSamples {
            let sampleLocation = sample.location!
            let distance = sampleLocation.distance(from: placeCentroid)
            distances.append(distance)

            // bearing and sector
            let bearing = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                .bearing(to: sampleLocation.coordinate)
            let sector = Int(bearing / 45.0) % 8
            sectorCounts[sector] += 1
            sectorDistanceSums[sector] += distance

            // speed
            if let speed = sample.speed, speed >= 0 {
                validSpeeds.append(speed)
            }

            // horizontal accuracy
            if let hAcc = sample.horizontalAccuracy {
                hAccValues.append(hAcc)
            }

            // vertical accuracy
            if let vAcc = sample.verticalAccuracy {
                vAccValues.append(vAcc)
            }

            // course validity
            if let course = sample.course, course >= 0 {
                courseValidCount += 1
            }
        }

        // compute mean magnitude per sector (0 for sectors with no samples)
        var sectorMagnitudes = Array(repeating: 0.0, count: 8)
        for i in 0..<8 {
            if sectorCounts[i] > 0 {
                sectorMagnitudes[i] = sectorDistanceSums[i] / Double(sectorCounts[i])
            }
        }

        // build the profile
        var profile = DriftProfile()
        profile.placeId = place.id
        profile.excursionSampleCount = excursionSamples.count
        profile.maxObservedDrift = distances.max() ?? 0
        profile.meanDriftDistance = distances.reduce(0, +) / Double(distances.count)
        profile.directionCounts = sectorCounts
        profile.directionMagnitudes = sectorMagnitudes
        profile.typicalSpeedMin = validSpeeds.min() ?? 0
        profile.typicalSpeedMax = validSpeeds.max() ?? 0
        profile.typicalHAccMin = hAccValues.min() ?? 0
        profile.typicalHAccMax = hAccValues.max() ?? 0
        profile.typicalVAccDuringDrift = median(of: vAccValues)
        profile.courseAvailability = Double(courseValidCount) / Double(excursionSamples.count)

        return profile
    }

    // MARK: - Place Scanning

    private static let maxSamplesToLoad = 50_000

    @PlacesActor
    public static func scanPlaces(_ placeIds: Set<String>) async {
        Log.info("DriftProfile scan starting: \(placeIds.count) places", subsystem: .misc)

        for placeId in placeIds {
            let place: Place?
            do {
                place = try await Database.pool.read { db in
                    try Place.fetchOne(db, id: placeId)
                }
            } catch {
                Log.error(error, subsystem: .places)
                continue
            }

            guard let place else { continue }

            // query all samples for visits at this place, most recent first
            let samples: [LocomotionSample]
            do {
                samples = try await Database.pool.read { [placeId] db in
                    try LocomotionSample
                        .filter(sql: "timelineItemId IN (SELECT itemId FROM TimelineItemVisit WHERE placeId = ?)", arguments: [placeId])
                        .filter(LocomotionSample.Columns.disabled == false)
                        .order(LocomotionSample.Columns.date.desc)
                        .limit(maxSamplesToLoad)
                        .fetchAll(db)
                }
            } catch {
                Log.error(error, subsystem: .database)
                continue
            }

            guard let profile = computeProfile(for: samples, place: place) else { continue }

            // only update if new profile has more data than stored
            do {
                try await Database.pool.write { [profile, placeId] db in
                    let existing = try DriftProfile
                        .filter { $0.placeId == placeId }
                        .fetchOne(db)

                    if let existing, existing.excursionSampleCount >= profile.excursionSampleCount {
                        return // stored profile is same or better quality
                    }

                    if let existing {
                        try existing.delete(db)
                    }

                    try profile.insert(db)
                }

                let topSector = profile.directionCounts.enumerated().max(by: { $0.element < $1.element })
                let sectorNames = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                let directionName = topSector.map { sectorNames[$0.offset] } ?? "?"
                let topMagnitude = topSector.map { profile.directionMagnitudes[$0.offset] } ?? 0

                Log.info(
                    "DriftProfile updated for place '\(place.name)': \(profile.excursionSampleCount) excursion samples, " +
                    "max drift \(Int(profile.maxObservedDrift))m, mean \(Int(profile.meanDriftDistance))m, " +
                    "primary direction \(directionName) (\(Int(topMagnitude))m mean)",
                    subsystem: .misc
                )
            } catch {
                Log.error(error, subsystem: .database)
            }
        }
    }

    // MARK: - Helpers

    private static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

}
