//
//  TimelineItem+Processing.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-10-19.
//

import Foundation
import CoreLocation

extension TimelineItem {

    @TimelineActor
    public func scoreForConsuming(_ item: TimelineItem) -> ConsumptionScore {
        return MergeScores.consumptionScoreFor(self, toConsume: item)
    }

    public var keepnessScore: Int {
        get throws {
            if try isWorthKeeping { return 2 }
            if try isValid { return 1 }
            return 0
        }
    }

    public var keepnessString: String {
        get throws {
            if try isWorthKeeping { return "keeper" }
            if try isValid { return "valid" }
            return "invalid"
        }
    }

    internal func willConsume(_ otherItem: TimelineItem) {
        if otherItem.isVisit {
            // if self.swarmCheckinId == nil, otherItem.swarmCheckinId != nil {
            //     self.swarmCheckinId = otherItem.swarmCheckinId
            // }
            // if self.customTitle == nil, otherItem.customTitle != nil {
            //     self.customTitle = otherItem.customTitle
            // }
        }
    }

    internal func isWithinMergeableDistance(of otherItem: TimelineItem) throws -> Bool {
        if try self.isNolo { return true }
        if try otherItem.isNolo { return true }

        if let gap = try distance(from: otherItem), gap <= maximumMergeableDistance(from: otherItem) { return true }

        // if the items overlap in time, any physical distance is acceptable
        if timeInterval(from: otherItem) < 0 { return true }

        return false
    }

    private func maximumMergeableDistance(from otherItem: TimelineItem) -> CLLocationDistance {
        if self.isVisit {
            return maximumMergeableDistanceForVisit(from: otherItem)
        } else {
            return maximumMergeableDistanceForTrip(from: otherItem)
        }
    }

    // VISIT <-> OTHER
    private func maximumMergeableDistanceForVisit(from otherItem: TimelineItem) -> CLLocationDistance {

        // VISIT <-> VISIT
        if otherItem.isVisit {
            return .greatestFiniteMagnitude
        }

        // VISIT <-> TRIP

        // visit-trip gaps less than this should be forgiven
        let minimum: CLLocationDistance = 150

        let timeSeparation = abs(self.timeInterval(from: otherItem))
        let rawMax = CLLocationDistance(otherItem.trip?.speed ?? 0 * timeSeparation * 4)

        return max(rawMax, minimum)
    }

    // TRIP <-> OTHER
    private func maximumMergeableDistanceForTrip(from otherItem: TimelineItem) -> CLLocationDistance {

        // TRIP <-> VISIT
        if otherItem.isVisit {
            return otherItem.maximumMergeableDistance(from: self)
        }

        // TRIP <-> TRIP

        let timeSeparation = abs(self.timeInterval(from: otherItem))

        let selfSpeed = self.trip?.speed ?? 0
        let otherSpeed = otherItem.trip?.speed ?? 0
        let maxSpeed = max(selfSpeed, otherSpeed)

        return CLLocationDistance(maxSpeed * timeSeparation * 50)
    }

    // MARK: -

    public func distance(from otherItem: TimelineItem) throws -> CLLocationDistance? {
        if self.isVisit {
            return try visit?.distance(from: otherItem)

        } else {
            if otherItem.isVisit {
                return try otherItem.visit?.distance(from: self)

            } else {
                return try distanceFromTripToTrip(otherItem)
            }
        }
    }

    private func distanceFromTripToTrip(_ otherItem: TimelineItem) throws -> CLLocationDistance? {
        guard self.isTrip, otherItem.isTrip else { fatalError() }

        guard let samples, let otherSamples = otherItem.samples else {
            throw TimelineError.samplesNotLoaded
        }

        guard let selfStart = dateRange?.start,
              let otherStart = otherItem.dateRange?.start else {
            return nil
        }

        if selfStart < otherStart {
            guard let selfEdge = samples.last?.location,
                  let otherEdge = otherSamples.first?.location else {
                return nil
            }
            return selfEdge.distance(from: otherEdge)

        } else {
            guard let selfEdge = samples.first?.location,
                  let otherEdge = otherSamples.last?.location else {
                return nil
            }
            return selfEdge.distance(from: otherEdge)
        }
    }

    // a negative value indicates overlapping items, thus the duration of their overlap
    public func timeInterval(from otherItem: TimelineItem) -> TimeInterval {
        guard let myRange = self.dateRange,
              let theirRange = otherItem.dateRange else {
            return .greatestFiniteMagnitude
        }

        // case 1: items overlap
        if let intersection = myRange.intersection(with: theirRange) {
            return -intersection.duration
        }

        // case 2: this item is entirely before the other item
        if myRange.end <= theirRange.start {
            return theirRange.start.timeIntervalSince(myRange.end)
        }

        // case 3: this item is entirely after the other item
        return myRange.start.timeIntervalSince(theirRange.end)
    }

    // TODO: need to look for Place, to use Place radius instead, if available
    // (old ArcPath has an overload for this)
    public func samplesInside(_ visit: TimelineItemVisit) throws -> [LocomotionSample] {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        return samples.filter { sample in
            if let location = sample.location {
                return visit.contains(location, sd: 1)
            }
            return false
        }
    }

    public func percentInside(_ visit: TimelineItemVisit) throws -> Double {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if samples.isEmpty { return 0 }

        let samplesInsideVisit = try self.samplesInside(visit)

        return Double(samplesInsideVisit.count) / Double(samples.count)
    }

    // MARK: -

    public func edgeSample(withOtherItemId otherItemId: String) throws -> LocomotionSample? {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if otherItemId == base.previousItemId {
            return samples.first
        }
        if otherItemId == base.nextItemId {
            return samples.last
        }

        return nil
    }

    public func secondToEdgeSample(withOtherItemId otherItemId: String) throws -> LocomotionSample? {
        guard let samples else {
            throw TimelineError.samplesNotLoaded
        }

        if otherItemId == base.previousItemId {
            return samples.second
        }
        if otherItemId == base.nextItemId {
            return samples.secondToLast
        }

        return nil
    }
    
}
