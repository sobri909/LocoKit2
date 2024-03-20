//
//  TimelineItem.swift
//
//
//  Created by Matt Greenfield on 18/3/24.
//

import Foundation
import CoreLocation
import GRDB

public class TimelineItem: FetchableRecord, Decodable, Identifiable, Hashable {
    public let base: TimelineItemBase
    public var visit: TimelineItemVisit?
    public let trip: TimelineItemTrip?
    public let samples: [LocomotionSample]?

    public var id: String { base.id }
    public var isVisit: Bool { base.isVisit }

    public func updateVisit() async {
        guard let samples, let visit, visit.isStale else { return }

        print("updateVisit() itemId: \(id)")

        visit.update(from: samples)
        do {
            try await Database.pool.write {
                _ = try visit.updateChanges($0)
            }
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }
    }

    public func updateTrip() async {
        guard let samples, let trip, trip.isStale else { return }

        print("updateTrip() itemId: \(id)")

        trip.update(from: samples)
        do {
            try await Database.pool.write {
                _ = try trip.updateChanges($0)
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

        Task {
            await updateVisit()
            await updateTrip()
        }
    }
}
