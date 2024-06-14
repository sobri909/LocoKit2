//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import CoreLocation
import Combine
import GRDB

public struct TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable {

    public var base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public var trip: TimelineItemTrip?
    public internal(set) var samples: [LocomotionSample]?

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var isTrip: Bool { !base.isVisit }
    public var dateRange: DateInterval { base.dateRange }
    public var source: String { base.source }
    public var disabled: Bool { base.disabled }
    public var deleted: Bool { base.deleted }
    public var samplesChanged: Bool { base.samplesChanged }
    
    public var debugShortId: String { String(id.split(separator: "-")[0]) }

    // MARK: -

    public var coordinates: [CLLocationCoordinate2D]? {
        return samples?.compactMap { $0.coordinate }.filter { $0.isUsable }
    }
    public mutating func fetchSamples() async {
        guard samplesChanged || samples == nil else {
            print("[\(debugShortId)] fetchSamples() skipping; no reason to fetch")
            return
        }

        do {
            let samplesRequest = base.samples.order(Column("date").asc)
            let fetchedSamples = try await Database.pool.read {
                try samplesRequest.fetchAll($0)
            }

            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    public func previousItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.previousItem(for: self)
    }

    public func nextItem(in list: TimelineLinkedList) async -> TimelineItem? {
        return await list.nextItem(for: self)
    }

    public mutating func breakEdges() {
        base.previousItemId = nil
        base.nextItemId = nil
    }
    public func edgeSample(withOtherItemId otherItemId: String) -> LocomotionSample? {
        if otherItemId == base.previousItemId {
            return samples?.first
        }
        if otherItemId == base.nextItemId {
            return samples?.last
        }
        return nil
    }

    // MARK: - Private

    private mutating func updateFrom(samples updatedSamples: [LocomotionSample]) async {
        guard samplesChanged else {
            print("[\(debugShortId)] updateFrom(samples:) skipping; no reason to update")
            return
        }

        let visitChanged = visit?.update(from: updatedSamples) ?? false
        let tripChanged = trip?.update(from: updatedSamples) ?? false
        base.samplesChanged = false

        let baseCopy = base
        let visitCopy = visit
        let tripCopy = trip
        do {
            try await Database.pool.write {
                if visitChanged { try visitCopy?.save($0) }
                if tripChanged { try tripCopy?.save($0) }
                try baseCopy.save($0)
            }
            
        } catch {
            logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, samples
    }

    // MARK: - Hashable

    public static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
