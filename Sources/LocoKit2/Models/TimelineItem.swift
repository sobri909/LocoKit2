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

@Observable
public class TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable {
    public let base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public let trip: TimelineItemTrip?
    public var samples: [LocomotionSample]?

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }
    public var samplesChanged: Bool { base.samplesChanged }

    public func fetchSamples() async {
        guard samplesChanged || samples == nil else { return }

        do {
            let fetchedSamples = try await Database.pool.read {
                try self.base.samples.order(Column("date").asc).fetchAll($0)
            }


            self.samples = fetchedSamples

            if samplesChanged {
                await updateFrom(samples: fetchedSamples)
            }

        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    private func updateFrom(samples updatedSamples: [LocomotionSample]) async {
        guard samplesChanged else { return }

        visit?.update(from: updatedSamples)
        trip?.update(from: updatedSamples)
        base.samplesChanged = false

        do {
            try await Database.pool.write {
                _ = try self.visit?.updateChanges($0)
                _ = try self.trip?.updateChanges($0)
                _ = try self.base.updateChanges($0)
            }
            
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case base, visit, trip, samples
    }
    
    public required init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        self.base = try container.decode(TimelineItemBase.self, forKey: CodingKeys.base)
        self.visit = try container.decodeIfPresent(TimelineItemVisit.self, forKey: CodingKeys.visit)
        self.trip = try container.decodeIfPresent(TimelineItemTrip.self, forKey: CodingKeys.trip)
        self.samples = try container.decodeIfPresent([LocomotionSample].self, forKey: CodingKeys.samples)

        if samplesChanged, let samples {
            Task { await updateFrom(samples: samples) }
        }
    }
}
