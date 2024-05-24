//
//  TimelineSegment.swift
//
//
//  Created by Matt Greenfield on 23/5/24.
//

import Foundation
import Combine
import GRDB

@Observable
public class TimelineSegment {

    public let dateRange: DateInterval
    public private(set) var timelineItems: [TimelineItem] = []

    @ObservationIgnored
    private var itemsObserver: AnyCancellable?

    @ObservationIgnored
    private var samplesObservers: [String: AnyCancellable] = [:]

    public init(dateRange: DateInterval) {
        self.dateRange = dateRange

        let itemsRequest = TimelineItemBase
            .including(optional: TimelineItemBase.visit)
            .including(optional: TimelineItemBase.trip)
            .filter(Column("endDate") > dateRange.start && Column("startDate") < dateRange.end)
            .order(Column("endDate").desc)

        self.itemsObserver = ValueObservation
            .trackingConstantRegion {
                try TimelineItem.fetchAll($0, itemsRequest)
            }
            .publisher(in: Database.pool)
            .sink { completion in
                if case .failure(let error) = completion {
                    DebugLogger.logger.error(error, subsystem: .database)
                }
            } receiveValue: { [weak self] (items: [TimelineItem]) in
                self?.updateItems(from: items)
            }
    }

    private func updateItems(from items: [TimelineItem]) {
        self.timelineItems = items

        for item in items {
            if samplesObservers[item.id] != nil { continue }

            print("updateItems() adding samples observer: \(item.id)")

            samplesObservers[item.id] = ValueObservation
                .trackingConstantRegion(item.base.samples.fetchAll)
                .publisher(in: Database.pool)
                .sink { completion in
                    if case .failure(let error) = completion {
                        DebugLogger.logger.error(error, subsystem: .database)
                    }
                } receiveValue: { samples in
                    item.updateSamples(samples)
                }
        }

    }

}
