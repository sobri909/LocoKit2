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
                if let self {
                    Task { await self.updateItems(from: items) }
                }
            }
    }

    private func updateItems(from updatedItems: [TimelineItem]) async {
        var mutableItems = updatedItems

        for index in mutableItems.indices {
            let itemCopy = mutableItems[index]
            if itemCopy.samplesChanged {
                await mutableItems[index].fetchSamples()

            } else {
                // copy over existing samples if available
                let localItem = timelineItems.first { $0.id == itemCopy.id }
                if let localItem, let samples = localItem.samples {
                    mutableItems[index].samples = samples

                } else { // need to fetch samples
                    await mutableItems[index].fetchSamples()
                }
            }
        }

        self.timelineItems = mutableItems
    }

}
