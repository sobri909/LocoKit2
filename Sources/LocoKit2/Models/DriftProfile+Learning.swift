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
        var validSpeeds: [Double] = []
        var hAccValues: [Double] = []
        var vAccValues: [Double] = []
        var courseValidCount = 0

        for sample in excursionSamples {
            let sampleLocation = sample.location!
            let distance = sampleLocation.distance(from: placeCentroid)
            distances.append(distance)

            // bearing and sector
            let bearing = self.bearing(
                from: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                to: sampleLocation.coordinate
            )
            let sector = Int(bearing / 45.0) % 8
            sectorCounts[sector] += 1

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

        // build the profile
        var profile = DriftProfile()
        profile.placeId = place.id
        profile.excursionSampleCount = excursionSamples.count
        profile.maxObservedDrift = distances.max() ?? 0
        profile.meanDriftDistance = distances.reduce(0, +) / Double(distances.count)
        profile.directionHistogram = sectorCounts
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

                let topSector = profile.directionHistogram.enumerated().max(by: { $0.element < $1.element })
                let sectorNames = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                let directionName = topSector.map { sectorNames[$0.offset] } ?? "?"

                Log.info(
                    "DriftProfile updated for place '\(place.name)': \(profile.excursionSampleCount) excursion samples, " +
                    "max drift \(Int(profile.maxObservedDrift))m, mean \(Int(profile.meanDriftDistance))m, " +
                    "primary direction \(directionName), " +
                    "speed \(String(format: "%.1f", profile.typicalSpeedMin))-\(String(format: "%.1f", profile.typicalSpeedMax)) m/s",
                    subsystem: .misc
                )
            } catch {
                Log.error(error, subsystem: .database)
            }
        }

        // recompute generic (fallback) profile
        await recomputeGenericProfile()
    }

    @PlacesActor
    private static func recomputeGenericProfile() async {
        do {
            let placeProfiles = try await Database.pool.read { db in
                try DriftProfile
                    .filter(DriftProfile.Columns.placeId != nil)
                    .fetchAll(db)
            }

            guard !placeProfiles.isEmpty else { return }

            let totalWeight = placeProfiles.reduce(0) { $0 + $1.excursionSampleCount }
            guard totalWeight > 0 else { return }

            var generic = DriftProfile()
            generic.placeId = nil

            // weighted averages for spatial values
            var weightedMaxDrift = 0.0
            var weightedMeanDrift = 0.0
            var weightedSpeedMin = 0.0
            var weightedSpeedMax = 0.0
            var weightedHAccMin = 0.0
            var weightedHAccMax = 0.0
            var weightedCourseAvail = 0.0
            var vAccValues: [Double] = []
            var totalHistogram = Array(repeating: 0, count: 8)

            for profile in placeProfiles {
                let weight = Double(profile.excursionSampleCount)
                weightedMaxDrift += profile.maxObservedDrift * weight
                weightedMeanDrift += profile.meanDriftDistance * weight
                weightedSpeedMin += profile.typicalSpeedMin * weight
                weightedSpeedMax += profile.typicalSpeedMax * weight
                weightedHAccMin += profile.typicalHAccMin * weight
                weightedHAccMax += profile.typicalHAccMax * weight
                weightedCourseAvail += profile.courseAvailability * weight

                if let vAcc = profile.typicalVAccDuringDrift {
                    vAccValues.append(vAcc)
                }

                for i in 0..<8 {
                    totalHistogram[i] += profile.directionHistogram[i]
                }
            }

            let divisor = Double(totalWeight)
            generic.excursionSampleCount = totalWeight
            generic.maxObservedDrift = weightedMaxDrift / divisor
            generic.meanDriftDistance = weightedMeanDrift / divisor
            generic.directionHistogram = totalHistogram
            generic.typicalSpeedMin = weightedSpeedMin / divisor
            generic.typicalSpeedMax = weightedSpeedMax / divisor
            generic.typicalHAccMin = weightedHAccMin / divisor
            generic.typicalHAccMax = weightedHAccMax / divisor
            generic.typicalVAccDuringDrift = median(of: vAccValues)
            generic.courseAvailability = weightedCourseAvail / divisor

            try await Database.pool.write { [generic] db in
                // remove old generic profile
                try DriftProfile
                    .filter(DriftProfile.Columns.placeId == nil)
                    .deleteAll(db)

                try generic.insert(db)
            }

            Log.info(
                "DriftProfile generic updated: \(placeProfiles.count) places, \(totalWeight) total excursion samples",
                subsystem: .misc
            )
        } catch {
            Log.error(error, subsystem: .database)
        }
    }

    // MARK: - Helpers

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLon = (to.longitude - from.longitude).radians
        let y = sin(dLon) * cos(to.latitude.radians)
        let x = cos(from.latitude.radians) * sin(to.latitude.radians) -
                sin(from.latitude.radians) * cos(to.latitude.radians) * cos(dLon)
        return (atan2(y, x).degrees + 360).truncatingRemainder(dividingBy: 360)
    }

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
