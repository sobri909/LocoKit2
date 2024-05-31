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
    public var samples: [LocomotionSample]?

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var samplesChanged: Bool { base.samplesChanged }
    public var debugShortId: String { String(id.split(separator: "-")[0]) }

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

            print("[\(debugShortId)] fetchSamples() samples: \(fetchedSamples.count)")

            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private mutating func updateFrom(samples updatedSamples: [LocomotionSample]) async {
        guard samplesChanged else {
            print("[\(debugShortId)] fetchSamples() skipping; no reason to update")
            return
        }

        print("[\(debugShortId)] updateFrom(samples:) count: \(updatedSamples.count)")

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
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, samples
    }

}
