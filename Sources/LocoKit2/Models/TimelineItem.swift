//
//  TimelineItem.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct TimelineItem: FetchableRecord, Codable, Identifiable, Hashable, Sendable {

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
                if let visit {
                    if visit.hasConfirmedPlace { return true }
                    if let customTitle = visit.customTitle, !customTitle.isEmpty { return true }
                }
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
                if let visit {
                    if visit.hasConfirmedPlace { return true }
                    if let customTitle = visit.customTitle, !customTitle.isEmpty { return true }
                }
                if dateRange.duration < TimelineItemVisit.minimumKeeperDuration { return false }
                return true

            } else { // Trips
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

    public var hasAssignment: Bool {
        if let visit {
            return visit.placeId != nil
        }
        if let trip {
            return trip.activityType != nil
        }
        return false
    }

    public var assignmentConfirmed: Bool {
        if let visit {
            return visit.confirmedPlace
        }
        if let trip {
            return trip.confirmedActivityType != nil
        }
        return false
    }

    public var assignmentCertain: Bool {
        if let visit {
            return !visit.uncertainPlace
        }
        if let trip {
            return !trip.uncertainActivityType
        }
        return false
    }

    // MARK: - Item creation

    public static func createItem(from samples: [LocomotionSample], isVisit: Bool, db: GRDB.Database) throws -> TimelineItem {
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

        try base.insert(db)
        try visit?.insert(db)
        try trip?.insert(db)
        for var sample in samples {
            try sample.updateChanges(db) {
                $0.timelineItemId = base.id
            }
        }

        let newItem = try TimelineItem
            .itemRequest(includeSamples: false)
            .filter(Column("id") == base.id)
            .fetchOne(db)

        guard let newItem else {
            throw TimelineError.itemNotFound
        }
        
        return newItem
    }

    public mutating func copyMetadata(from otherItem: TimelineItem, db: GRDB.Database) throws {
        if var thisVisit = self.visit, let otherVisit = otherItem.visit {
            try thisVisit.updateChanges(db) { visit in
                visit.copyMetadata(from: otherVisit)
            }
        }
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
