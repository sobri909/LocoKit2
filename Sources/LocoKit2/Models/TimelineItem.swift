//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import CoreLocation
import Combine
@preconcurrency import GRDB

public struct TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable, Sendable {

    public var base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public var trip: TimelineItemTrip?
    public var place: Place?

    public internal(set) var samples: [LocomotionSample]? {
        didSet {
            if let samples {
                self.segments = Self.collateSegments(from: samples, disabled: disabled)
            } else {
                self.segments = nil
            }
        }
    }

    public internal(set) var segments: [ItemSegment]?

    // MARK: -

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var isTrip: Bool { !base.isVisit }
    public var dateRange: DateInterval? { base.dateRange }
    public var source: String { base.source }
    public var disabled: Bool { base.disabled }
    public var deleted: Bool { base.deleted }
    public var samplesChanged: Bool { base.samplesChanged }
    
    public var debugShortId: String { String(id.split(separator: "-")[0]) }

    public var coordinates: [CLLocationCoordinate2D]? {
        return samples?.usableLocations().compactMap { $0.coordinate }
    }

    public var startTimeZone: TimeZone? {
        return samples?.first?.localTimeZone
    }

    public var endTimeZone: TimeZone? {
        return samples?.last?.localTimeZone
    }

    // MARK: - Relationships

    @TimelineActor
    public func previousItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.previousItem(for: self)
    }

    @TimelineActor
    public func nextItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.nextItem(for: self)
    }

    // MARK: -

    public var isValid: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            guard let dateRange else { return false }

            if isVisit {
                // Visit specific validity logic
                if samples.isEmpty { return false }
                if try isNolo { return false }
                if dateRange.duration < TimelineItemVisit.minimumValidDuration { return false }
                return true
                
            } else {
                // Trip specific validity logic
                if samples.count < TimelineItemTrip.minimumValidSamples { return false }
                if dateRange.duration < TimelineItemTrip.minimumValidDuration { return false }
                if let distance = trip?.distance, distance < TimelineItemTrip.minimumValidDistance { return false }
                return true
            }
        }
    }

    public var isInvalid: Bool {
        get throws { try !isValid }
    }

    public var isWorthKeeping: Bool {
        get throws {
            if try !isValid { return false }

            guard let dateRange else { return false }

            if isVisit {
                // Visit-specific worth keeping logic
                if dateRange.duration < TimelineItemVisit.minimumKeeperDuration { return false }
                return true
            } else {
                // Trip-specific worth keeping logic
                if dateRange.duration < TimelineItemTrip.minimumKeeperDuration { return false }
                if let distance = trip?.distance, distance < TimelineItemTrip.minimumKeeperDistance { return false }
                return true
            }
        }
    }

    public var isDataGap: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            if isVisit { return false }
            if samples.isEmpty { return false }

            return samples.allSatisfy { $0.recordingState == .off }
        }
    }

    public var isNolo: Bool {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            if try isDataGap { return false }
            return samples.allSatisfy { $0.location == nil }
        }
    }

    // MARK: - Display strings

    public var typeString: String {
        get throws {
            if try isDataGap { return "datagap" }
            if try isNolo    { return "nolo" }
            if isVisit       { return "visit" }
            return "trip"
        }
    }

    public var title: String {
        get throws {
            if try isDataGap {
                return "Data Gap"
            }

            if let trip {
                if let activityType = trip.activityType {
                    return activityType.displayName.capitalized
                }
                return "Transport"
            }

            // must be a visit
            if let place {
                return place.name
            }

            if try isWorthKeeping {
                return "Unknown Place"
            }

            return "Brief Stop"
        }
    }

    public var description: String {
        get throws {
            String(format: "%@ %@", try keepnessString, try typeString)
        }
    }

    public func startString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let startDate = dateRange?.start else { return nil }
        return Self.dateString(
            for: startDate,
            timeZone: startTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative
        )
    }

    public func endString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let endDate = dateRange?.end else { return nil }
        return Self.dateString(
            for: endDate,
            timeZone: endTimeZone ?? TimeZone.current,
            dateStyle: dateStyle,
            timeStyle: timeStyle,
            relative: relative
        )
    }

    public static func dateString(for date: Date, timeZone: TimeZone = TimeZone.current, dateStyle: DateFormatter.Style = .none,
                    timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        dateFormatter.timeZone = timeZone
        dateFormatter.doesRelativeDateFormatting = relative
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string(from: date)
    }

    static let dateFormatter = DateFormatter()

    // MARK: - Item creation

    public static func createItem(from samples: [LocomotionSample], isVisit: Bool) async throws -> TimelineItem {
        let base = TimelineItemBase(isVisit: isVisit)
        let visit: TimelineItemVisit?
        let trip: TimelineItemTrip?

        if isVisit {
            visit = TimelineItemVisit(itemId: base.id, samples: samples)
            trip = nil
        } else {
            trip = TimelineItemTrip(itemId: base.id, samples: samples)
            visit = nil
        }

        let newItem = try await Database.pool.write { [base, visit, trip] in
            try base.save($0)
            try visit?.save($0)
            try trip?.save($0)
            for var sample in samples {
                try sample.updateChanges($0) {
                    $0.timelineItemId = base.id
                }
            }

            return try TimelineItem
                .itemRequest(includeSamples: false)
                .filter(Column("id") == base.id)
                .fetchOne($0)
        }

        guard let newItem else {
            throw TimelineError.itemNotFound
        }
        
        return newItem
    }

    // MARK: - Item fetching

    public static func fetchItem(itemId: String, includeSamples: Bool, includePlace: Bool = false) async throws -> TimelineItem? {
        return try await Database.pool.read {
            return try itemRequest(includeSamples: includeSamples, includePlaces: includePlace)
                .filter(Column("id") == itemId)
                .fetchOne($0)
        }
    }

    public static func itemRequest(includeSamples: Bool, includePlaces: Bool = false) -> QueryInterfaceRequest<TimelineItem> {
        var request = TimelineItemBase
            .including(optional: TimelineItemBase.trip)

        if includePlaces {
            request = request.including(
                optional: TimelineItemBase.visit
                    .aliased(TableAlias(name: "visit"))
                    .including(
                        optional: TimelineItemVisit.place
                            .aliased(TableAlias(name: "place"))
                    )
            )
        } else {
            request = request.including(optional: TimelineItemBase.visit.aliased(TableAlias(name: "visit")))
        }

        if includeSamples {
            request = request.including(all: TimelineItemBase.samples.order(Column("date").asc))
        }

        return request.asRequest(of: TimelineItem.self)
    }

    // MARK: - Sample fetching

    public mutating func fetchSamples(forceFetch: Bool = false) async {
        guard forceFetch || samplesChanged || samples == nil else {
            print("[\(debugShortId)] fetchSamples() skipping; no reason to fetch")
            return
        }

        do {
            let fetchedSamples = try await Database.pool.read { [base] in
                try base.samples
                    .order(Column("date").asc)
                    .fetchAll($0)
            }

            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    private static func collateSegments(from samples: [LocomotionSample], disabled: Bool) -> [ItemSegment] {
        var segments: [ItemSegment] = []
        var currentSamples: [LocomotionSample] = []

        for sample in samples where sample.disabled == disabled {
            if currentSamples.isEmpty || sample.activityType == currentSamples.first?.activityType {
                currentSamples.append(sample)
            } else {
                if let segment = ItemSegment(samples: currentSamples) {
                    segments.append(segment)
                }
                currentSamples = [sample]
            }
        }

        // add the last segment if there are any remaining samples
        if !currentSamples.isEmpty, let segment = ItemSegment(samples: currentSamples) {
            segments.append(segment)
        }

        return segments
    }

    public mutating func classifySamples() async {
        guard let samples else { return }
        guard let results = await ActivityClassifier.highlander.results(for: samples) else { return }

        do {
            self.samples = try await Database.pool.write { db in
                var updatedSamples: [LocomotionSample] = []
                for var mutableSample in samples {
                    if let result = results.perSampleResults[mutableSample.id] {
                        if mutableSample.classifiedActivityType != result.bestMatch.activityType {
                            try mutableSample.updateChanges(db) {
                                $0.classifiedActivityType = result.bestMatch.activityType
                            }
                        }
                    }
                    updatedSamples.append(mutableSample)
                }
                return updatedSamples
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }
    
    // MARK: - Activity type

    public mutating func changeActivityType(to confirmedType: ActivityType) async throws {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        var samplesToConfirm: [LocomotionSample] = []

        for sample in samples {
            // let confident stationary samples survive
            if sample.hasUsableCoordinate, sample.activityType == .stationary {
                if let typeScore = await sample.classifierResults?[.stationary]?.score, typeScore > 0.5 {
                    continue
                }
            }

            // let manual bogus samples survive
            if sample.confirmedActivityType == .bogus { continue }

            samplesToConfirm.append(sample)
        }

        if !samplesToConfirm.isEmpty {
            do {
                let changedSamples = try await Database.pool.write { [samplesToConfirm] db in
                    var changed: [LocomotionSample] = []
                    for var sample in samplesToConfirm where sample.confirmedActivityType != confirmedType {
                        try sample.updateChanges(db) {
                            $0.confirmedActivityType = confirmedType
                        }
                        changed.append(sample)
                    }
                    return changed
                }

                // queue updates for the ML models
                await CoreMLModelUpdater.highlander.queueUpdatesForModelsContaining(changedSamples)

                // samples have changed yo
                await fetchSamples(forceFetch: true)

            } catch {
                logger.error(error, subsystem: .database)
                return
            }
        }

        // if we're forcing it to stationary, extract all the stationary segments
        if confirmedType == .stationary, let segments {
            var newItems: [TimelineItem] = []
            for segment in segments where segment.activityType == .stationary {
                if let newItem = try await TimelineProcessor.extractItem(for: segment, isVisit: true) {
                    newItems.append(newItem)
                }
            }

            // cleanup after all that damage
            await TimelineProcessor.process(newItems)

        } else {
            // need to reprocess from self after the changes
            await TimelineProcessor.processFrom(itemId: self.id)
        }
    }

    public func cleanupSamples() async {
        if isVisit {
            await cleanupVisitSamples()
        } else {
            await cleanupTripSamples()
        }
    }

    private func cleanupTripSamples() async {
        guard isTrip, let tripActivityType = trip?.activityType else { return }

        do {
            let samplesForCleanup = try await tripSamplesForCleanup

            let updatedSamples = try await Database.pool.write { db in
                var updated: [LocomotionSample] = []
                for var sample in samplesForCleanup {
                    try sample.updateChanges(db) {
                        $0.confirmedActivityType = tripActivityType
                    }
                    updated.append(sample)
                }
                return updated
            }

            if !updatedSamples.isEmpty {
                await CoreMLModelUpdater.highlander.queueUpdatesForModelsContaining(updatedSamples)
            }

        } catch {
            logger.error(error, subsystem: .activitytypes)
        }
    }

    private func cleanupVisitSamples() async {
        guard isVisit, let visit else { return }

        do {
            let samplesForCleanup = try visitSamplesForCleanup

            let updatedSamples = try await Database.pool.write { db in
                var updated: [LocomotionSample] = []
                for var sample in samplesForCleanup {
                    try sample.updateChanges(db) { sample in
                        if let location = sample.location {
                            let isInside = if let place = self.place {
                                place.contains(location, sd: 3)
                            } else {
                                visit.contains(location, sd: 3)
                            }

                            if isInside { // inside radius = stationary
                                sample.confirmedActivityType = .stationary
                            } else { // outside radius = bogus
                                sample.confirmedActivityType = .bogus
                            }
                        } else { // treat nolos as inside the radius
                            sample.confirmedActivityType = .stationary
                        }
                    }
                    updated.append(sample)
                }
                return updated
            }

            if !updatedSamples.isEmpty {
                await CoreMLModelUpdater.highlander.queueUpdatesForModelsContaining(updatedSamples)
            }

        } catch {
            logger.error(error, subsystem: .timeline)
        }
    }

    public var haveSamplesForCleanup: Bool {
        get async {
            do {
                if isVisit {
                    return try !visitSamplesForCleanup.isEmpty
                } else {
                    return try await !tripSamplesForCleanup.isEmpty
                }
            } catch {
                logger.error(error, subsystem: .timeline)
                return false
            }
        }
    }

    private var tripSamplesForCleanup: [LocomotionSample] {
        get async throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            guard isTrip, let tripActivityType = trip?.activityType else { return [] }

            var filteredSamples: [LocomotionSample] = []
            for sample in samples {
                if sample.confirmedActivityType != nil { continue } // don't mess with already confirmed
                if sample.activityType == tripActivityType { continue } // don't mess with already matching

                // let confident stationary samples survive
                if sample.hasUsableCoordinate, sample.activityType == .stationary {
                    if let typeScore = await sample.classifierResults?[.stationary]?.score, typeScore > 0.5 {
                        continue
                    }
                }

                filteredSamples.append(sample)
            }

            return filteredSamples
        }
    }

    private var visitSamplesForCleanup: [LocomotionSample] {
        get throws {
            guard let samples else {
                throw TimelineError.samplesNotLoaded
            }

            return samples.filter {
                if $0.confirmedActivityType != nil { return false } // don't mess with already confirmed
                if $0.activityType == .stationary { return false } // don't mess with already stationary
                return true
            }
        }
    }

    // MARK: - Sample pruning

    public func pruneSamples() async throws {
        if isVisit {
            try await pruneVisitSamples()
        } else {
            try await pruneTripSamples()
        }
    }

    public func pruneTripSamples() async throws {
        guard isTrip, let trip = trip, let samples else {
            throw TimelineError.invalidItem("Can only prune Trips with samples")
        }
        guard let activityType = trip.activityType else {
            throw TimelineError.invalidItem("Trip requires activityType for pruning")
        }

        let maxInterval: TimeInterval
        if ActivityType.workoutTypes.contains(activityType) {
            maxInterval = 2.0
        } else if activityType == .airplane {
            maxInterval = 15.0
        } else {
            maxInterval = 6.0
        }

        let epsilon: CLLocationDistance
        if activityType == .airplane {
            epsilon = 100
        } else if ActivityType.workoutTypes.contains(activityType) {
            epsilon = 5 // all human-powered modes
        } else {
            epsilon = 25 // vehicles
        }
        
        let sortedSamples = samples.sorted { $0.date < $1.date }
        let points = sortedSamples.enumerated().compactMap { index, sample -> (coordinate: CLLocationCoordinate2D, date: Date, index: Int)? in
            guard let coordinate = sample.coordinate, coordinate.isUsable else { return nil }
            return (coordinate, sample.date, index)
        }

        guard points.count > 2 else { return }

        let keepIndices = RamerDouglasPeucker.simplifyDebug(coordinates: points, maxInterval: maxInterval, epsilon: epsilon)

        print("pruneTripSamples() maxInterval: \(maxInterval), epsilon: \(epsilon), points: \(points.count), keepIndices: \(keepIndices.count)")

        try await Database.pool.write { db in
            for (index, sample) in sortedSamples.enumerated() {
                if !keepIndices.contains(index) {
                    try sample.delete(db)
                }
            }
        }
    }

    func pruneVisitSamples() async throws {
        guard isVisit, let dateRange = dateRange, let samples = samples else {
            throw TimelineError.invalidItem("Can only prune Visits with samples")
        }

        print("pruneVisitSamples() starting with \(samples.count) samples")

        let startEdgeEnd = dateRange.start + .minutes(30)
        let endEdgeStart = dateRange.end - .minutes(30)
        let maxGap: TimeInterval = .minutes(2)

        var keepSamples: Set<String> = []
        var edgeCount = 0
        var nonStationaryCount = 0
        var middleCount = 0
        var gapSizes: [TimeInterval] = []

        // first pass: keep all edge and non-stationary samples
        for sample in samples {
            // Always keep non-stationary samples
            if sample.activityType != .stationary {
                keepSamples.insert(sample.id)
                nonStationaryCount += 1
                continue
            }

            // Keep edge samples
            if sample.date <= startEdgeEnd || sample.date >= endEdgeStart {
                keepSamples.insert(sample.id)
                edgeCount += 1
                continue
            }
        }

        print("- After first pass: keeping \(keepSamples.count) edge/non-stationary samples")

        // get remaining samples to process
        var middleSamples = samples.filter { !keepSamples.contains($0.id) }
        print("- Found \(middleSamples.count) middle samples to process")

        // rolling window approach
        var rollingWindow: [LocomotionSample] = []

        for sample in middleSamples {
            rollingWindow.append(sample)

            // if we've accumulated 2+ mins of samples
            if let firstInWindow = rollingWindow.first,
               sample.date - firstInWindow.date >= maxGap {

                // pick best sample from window
                if let bestSample = chooseBestSample(from: rollingWindow) {
                    keepSamples.insert(bestSample.id)
                    middleCount += 1

                    // track gap from previous kept sample for stats
                    if let previousDate = rollingWindow.first?.date {
                        let gap = bestSample.date - previousDate
                        gapSizes.append(gap)
                        print("- Kept sample at \(bestSample.date.formatted(date: .omitted, time: .standard)) (window: \(String(format: "%.1f", gap)) seconds)")
                    }

                    // remove everything up to and including kept sample
                    if let keptIndex = rollingWindow.firstIndex(where: { $0.id == bestSample.id }) {
                        rollingWindow.removeFirst(keptIndex + 1)
                    }
                }
            }
        }

        // handle any remaining window
        if !rollingWindow.isEmpty {
            if let bestSample = chooseBestSample(from: rollingWindow) {
                keepSamples.insert(bestSample.id)
                middleCount += 1

                if let previousDate = rollingWindow.first?.date {
                    let gap = bestSample.date - previousDate
                    gapSizes.append(gap)
                    print("- Final kept sample at \(bestSample.date.formatted(date: .omitted, time: .standard)) (window: \(String(format: "%.1f", gap)) seconds)")
                }
            }
        }

        let avgGap = gapSizes.isEmpty ? 0 : gapSizes.reduce(0, +) / Double(gapSizes.count)
        let maxFoundGap = gapSizes.max() ?? 0

        print("""
       pruneVisitSamples() results:
       - Total samples: \(samples.count)
       - Keeping \(keepSamples.count) samples (\(Int((Double(keepSamples.count) / Double(samples.count)) * 100))%)
       - Edge samples: \(edgeCount)
       - Non-stationary: \(nonStationaryCount)
       - Middle gaps: \(middleCount)
       - Average gap: \(String(format: "%.1f", avgGap)) seconds
       - Maximum gap: \(String(format: "%.1f", maxFoundGap)) seconds
       """)

//        try await Database.pool.write { [keepSamples] db in
//            for sample in samples {
//                if !keepSamples.contains(sample.id) {
//                    try sample.delete(db)
//                }
//            }
//        }
    }

    private func chooseBestSample(from candidates: [LocomotionSample]) -> LocomotionSample? {
        guard !candidates.isEmpty else { return nil }

        // Sort by accuracy (higher accuracy = lower number = better)
        // For equal accuracies, prefer newer samples
        // Samples without horizontalAccuracy go last
        return candidates
            .sorted { lhs, rhs in
                // if either lacks accuracy, it loses
                guard let lhsAccuracy = lhs.horizontalAccuracy else { return false }
                guard let rhsAccuracy = rhs.horizontalAccuracy else { return true } // rhs has no accuracy, lhs wins

                // both have accuracy - compare
                if lhsAccuracy == rhsAccuracy {
                    return lhs.date > rhs.date // newer samples first
                }
                return lhsAccuracy < rhsAccuracy
            }
            .first
    }

    // MARK: - Updating Visit and Trip

    private mutating func updateFrom(samples updatedSamples: [LocomotionSample]) async {
        guard samplesChanged else {
            print("[\(debugShortId)] updateFrom(samples:) skipping; no reason to update")
            return
        }

        let oldBase = base
        let oldTrip = trip
        let oldVisit = visit

        await visit?.update(from: updatedSamples)
        await trip?.update(from: updatedSamples)

        // TODO: this triggers db observers. would be nice if it didn't
        base.samplesChanged = false

        do {
            try await Database.pool.write { [base, visit, trip] db in
                try base.updateChanges(db, from: oldBase)
                if let oldVisit {
                    try visit?.updateChanges(db, from: oldVisit)
                }
                if let oldTrip {
                    try trip?.updateChanges(db, from: oldTrip)
                }
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, place, samples
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        base = try container.decode(TimelineItemBase.self, forKey: .base)
        visit = try container.decodeIfPresent(TimelineItemVisit.self, forKey: .visit)
        trip = try container.decodeIfPresent(TimelineItemTrip.self, forKey: .trip)
        place = try container.decodeIfPresent(Place.self, forKey: .place)
        samples = try container.decodeIfPresent([LocomotionSample].self, forKey: .samples)
        if let samples {
            segments = Self.collateSegments(from: samples, disabled: base.disabled)
        }
    }

}
