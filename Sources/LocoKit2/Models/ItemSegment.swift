//
//  ItemSegment.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-09-25.
//

import Foundation

public struct ItemSegment: Hashable, Sendable {

    public let samples: [LocomotionSample]
    public let dateRange: DateInterval

    init?(samples: [LocomotionSample]) {
        if samples.isEmpty {
            return nil
        }

        let dates = samples.map { $0.date }
        guard let startDate = dates.min(), let endDate = dates.max() else {
            return nil
        }

        self.samples = samples
        self.dateRange = DateInterval(start: startDate, end: endDate)
    }

}
