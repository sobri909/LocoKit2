//
//  Place+Stats.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 28/12/2024.
//

import Foundation
import GRDB

extension Place {

    @PlacesActor
    public func updateVisitStats() async {
        do {
            logger.info("UPDATING: \(name)", subsystem: .places)

            let currentItemId = await TimelineRecorder.currentItemId

            let visits = try await Database.pool.read { [id] db in
                try TimelineItem
                    .itemRequest(includeSamples: true, includePlaces: true)
                    .filter(sql: "visit.placeId = ?", arguments: [id])
                    .filter(Column("deleted") == false)
                    .fetchAll(db)
            }

            if visits.isEmpty {
                try await Database.pool.write { [self] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = 0
                        $0.visitDays = 0
                        $0.isStale = false
                        $0.arrivalTimes = nil
                        $0.leavingTimes = nil
                        $0.visitDurations = nil
                    }
                }
                logger.info("UPDATED: \(name)", subsystem: .places)
                return
            }

            // count unique visit days using place's timezone
            var calendar = Calendar.current
            calendar.timeZone = localTimeZone ?? .current

            let uniqueDays = Set<Date>(visits.compactMap {
                return $0.dateRange?.start.startOfDay(in: calendar)
            })

            let confirmedVisits = visits.filter { $0.visit?.confirmedPlace == true }
            let samples = confirmedVisits.flatMap { $0.samples ?? [] }

            let occupancyTimes = buildOccupancyTimes(from: confirmedVisits, in: calendar)

            // Only update if we have valid data to update with
            if let center = samples.weightedCenter() {
                let radius = samples.radius(from: center.location)

                let boundedMean = radius.mean.clamped(min: Place.minimumPlaceRadius, max: Place.maximumPlaceRadius)
                let boundedSD = radius.sd.clamped(min: 0, max: Place.maximumPlaceRadius)

                // use all visits for counts, samples, and arrival times
                let visitStarts = confirmedVisits.compactMap { $0.dateRange?.start }

                // filter out currentItem for leaving times and durations
                let statsVisits = confirmedVisits.filter { $0.id != currentItemId }
                let visitEnds = statsVisits.compactMap { $0.dateRange?.end }
                let visitDurations = statsVisits.compactMap { $0.dateRange?.duration }

                try await Database.pool.write { [self, occupancyTimes] db in
                    var mutableSelf = self
                    try mutableSelf.updateChanges(db) {
                        $0.visitCount = visits.count
                        $0.visitDays = uniqueDays.count
                        $0.latitude = center.latitude
                        $0.longitude = center.longitude
                        $0.radiusMean = boundedMean
                        $0.radiusSD = boundedSD
                        $0.isStale = false
                        $0.arrivalTimes = Histogram.forTimeOfDay(dates: visitStarts, timeZone: localTimeZone ?? .current)
                        $0.leavingTimes = Histogram.forTimeOfDay(dates: visitEnds, timeZone: localTimeZone ?? .current)
                        $0.visitDurations = Histogram.forDurations(intervals: visitDurations)
                        $0.occupancyTimes = occupancyTimes
                    }
                    
                    Task { await mutableSelf.updateRTree() }
                }

                logger.info("UPDATED: \(name)", subsystem: .places)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public func leavingProbabilityFor(duration: TimeInterval, date: Date = .now) -> Double? {
        guard let leavingTimes = leavingTimes,
              let visitDurations = visitDurations else {
            return nil
        }

        // Get time of day in place's timezone
        var calendar = Calendar.current
        calendar.timeZone = localTimeZone ?? .current
        let timeOfDay = date.sinceStartOfDay(in: calendar)

        // both need to have non-nil probabilities for AND probability to make sense
        guard let timeBasedProbability = leavingTimes.probability(for: timeOfDay) else { return nil }
        guard let durationBasedProbability = visitDurations.probability(for: duration) else { return nil }

        // Using AND probability for most conservative estimate
        return timeBasedProbability * durationBasedProbability
    }
    
    private func buildOccupancyTimes(from visits: [TimelineItem], in calendar: Calendar) -> [Histogram] {
        var dayOfWeekValues: [[Double]] = Array(repeating: [], count: 8) // 0 = all days, 1-7 = weekdays
        
        // walk through each visit in 1-min steps
        for visit in visits {
            guard let range = visit.dateRange else { continue }
            var current = range.start
            
            while current <= range.end {
                let timeOfDay = current.sinceStartOfDay(in: calendar)
                
                // add to all days (index 0)
                dayOfWeekValues[0].append(timeOfDay)
                
                // add to specific weekday (index 1-7)
                let weekday = calendar.component(.weekday, from: current)
                dayOfWeekValues[weekday].append(timeOfDay)
                
                current += .minutes(1)
            }
        }
        
        // create Histograms in order (all days first, then each weekday)
        var histograms: [Histogram] = []
        for values in dayOfWeekValues where !values.isEmpty {
            if let histogram = Histogram(values: values) {
                histograms.append(histogram)
            }
        }

        return histograms
    }

}
