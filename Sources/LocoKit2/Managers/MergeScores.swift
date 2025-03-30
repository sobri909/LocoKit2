//
//  MergeScores.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 15/12/16.
//  Copyright © 2016 Big Paua. All rights reserved.
//

import Foundation

public enum ConsumptionScore: Int {
    case perfect = 5
    case high = 4
    case medium = 3
    case low = 2
    case veryLow = 1
    case impossible = 0
}

@TimelineActor
public final class MergeScores {

    // MARK: - SOMETHING <- SOMETHING
    static func consumptionScoreFor(_ consumer: TimelineItem, toConsume consumee: TimelineItem) async -> ConsumptionScore {
        guard let consumerSamples = consumer.samples else { return .impossible }
        guard let consumeeSamples = consumee.samples else { return .impossible }

        // deadmen can't consume anyone
        if consumer.deleted { return .impossible }

        // disabled can't consume or be consumed
        if consumer.disabled || consumee.disabled { return .impossible }

        // can't consume a different source
        if consumer.source != consumee.source { return .impossible }

        // if consumee is currentItem and not a keeper, no merge allowed
        if consumee.id == TimelineRecorder.currentItemId {
            do {
                if try !consumee.isWorthKeeping {
                    return .impossible
                }
            } catch {
                logger.error(error, subsystem: .timeline)
                return .impossible
            }
        }

        // if consumee has zero samples, call it a perfect merge
        if consumeeSamples.isEmpty { return .perfect }

        // if consumer has zero samples, call it impossible
        if consumerSamples.isEmpty { return .impossible }

        do {
            // data gaps can only consume data gaps
            if try consumer.isDataGap { return (try consumee.isDataGap) ? .perfect : .impossible }

            // anyone can consume an invalid data gap, but no one can consume a valid data gap
            if try consumee.isDataGap { return (try consumee.isInvalid) ? .medium : .impossible }

            // nolos can only consume nolos
            if try consumer.isNolo { return (try consumee.isNolo) ? .perfect : .impossible }

            // anyone can consume an invalid nolo
            if try consumee.isNolo && consumee.isInvalid { return .medium }

            // test for impossible separation distance
            guard try consumer.isWithinMergeableDistance(of: consumee) else { return .impossible }

            // visit <- something
            if consumer.isVisit {
                return consumptionScoreFor(visit: consumer, toConsume: consumee)
            } else { // trip <- something
                return try await consumptionScoreFor(trip: consumer, toConsume: consumee)
            }

        } catch {
            logger.error("MergeScores.consumptionScoreFor() \(error)", subsystem: .timeline)
            return .impossible
        }
    }

    // MARK: - TRIP <- SOMETHING
    private static func consumptionScoreFor(trip consumer: TimelineItem, toConsume consumee: TimelineItem) async throws -> ConsumptionScore {
        guard consumer.isTrip else { fatalError() }

        // consumer is invalid
        if try consumer.isInvalid {

            // invalid <- invalid
            if try consumee.isInvalid { return .veryLow }

            // invalid <- valid
            return .impossible
        }

        // trip <- visit
        if consumee.isVisit { return try consumptionScoreFor(trip: consumer, toConsumeVisit: consumee) }

        // trip <- trip
        if consumee.isTrip { return try await consumptionScoreFor(trip: consumer, toConsumeTrip: consumee) }

        return .impossible
    }
    
    // MARK: - TRIP <- VISIT
    private static func consumptionScoreFor(trip consumer: TimelineItem, toConsumeVisit consumee: TimelineItem) throws -> ConsumptionScore {
        guard consumer.isTrip, consumee.isVisit else { fatalError() }

        // can't consume a keeper visit
        if try consumee.isWorthKeeping { return .impossible }

        // consumer is keeper
        if try consumer.isWorthKeeping {

            // keeper <- invalid
            if try consumee.isInvalid { return .medium }

            // keeper  <- valid
            return .low
        }
        
        // consumer is valid
        if try consumer.isValid {

            // valid <- invalid
            if try consumee.isInvalid { return .low }

            // valid <- valid
            return .veryLow
        }
        
        // consumer is invalid (actually already dealt with in previous method)
        return .impossible
    }

    // MARK: - TRIP <- TRIP
    private static func consumptionScoreFor(trip consumer: TimelineItem, toConsumeTrip consumee: TimelineItem) async throws -> ConsumptionScore {
        guard consumer.isTrip, consumee.isTrip else { fatalError() }
        guard let consumerTrip = consumer.trip, let consumeeTrip = consumee.trip else { fatalError() }

        let consumerType = consumerTrip.activityType
        let consumeeType = consumeeTrip.activityType

        // no types means it's a random guess (possibly in background)
        if consumerType == nil && consumeeType == nil { return .medium }

        // perfect type match
        if consumeeType == consumerType { return .perfect }

        // can't consume a keeper path
        if try consumee.isWorthKeeping { return .impossible }

        // a path with nil type can't consume anyone
        guard let scoringType = consumerType else { return .impossible }

        // TODO: this is bad. it means background/foreground processing acts different. grr
        // check consumee's classifier results for compatibility with consumer's type
        guard let classifierResults = await consumee.samples?.first?.classifierResults,
              let typeResult = classifierResults[scoringType] else {
            return .veryLow
        }

        // convert score to percentage for easier thresholds
        let typeScore = Int(floor(typeResult.score * 100))

        switch typeScore {
        case 75...Int.max:  // 0.75-1.0 -> very strong match
            return .perfect
        case 50...74:       // 0.5-0.74 -> good match
            return .high
        case 25...49:       // 0.25-0.49 -> possible match
            return .medium
        case 10...24:       // 0.1-0.24 -> weak match
            return .low
        default:            // < 0.1 -> very weak match
            return .veryLow
        }
    }

    // MARK: - VISIT <- SOMETHING
    private static func consumptionScoreFor(visit consumer: TimelineItem, toConsume consumee: TimelineItem) -> ConsumptionScore {
        guard consumer.isVisit else { fatalError() }

        // visit <- visit
        if consumee.isVisit { return consumptionScoreFor(visit: consumer, toConsumeVisit: consumee) }

        // visit <- trip
        if consumee.isTrip { return consumptionScoreFor(visit: consumer, toConsumeTrip: consumee) }

        return .impossible
    }
    
    // MARK: - VISIT <- VISIT
    private static func consumptionScoreFor(visit consumer: TimelineItem, toConsumeVisit consumee: TimelineItem) -> ConsumptionScore {
        guard consumer.isVisit, consumee.isVisit else { fatalError() }
        guard let consumerVisit = consumer.visit, let consumeeVisit = consumee.visit else { fatalError() }
        guard let consumerRange = consumer.dateRange, let consumeeRange = consumee.dateRange else { return .impossible }

        // check if either has a custom title
        if consumerVisit.customTitle != nil || consumeeVisit.customTitle != nil {
            return .impossible
        }
        
        // both have confirmed places?
        if consumerVisit.hasConfirmedPlace && consumeeVisit.hasConfirmedPlace {

            // same confirmed place
            if consumerVisit.hasSamePlaceAs(consumeeVisit) {

                // favour the one with longer duration
                return consumerRange.duration > consumeeRange.duration ? .perfect : .high

            } else { // different confirmed places - no merge
                return .impossible
            }
        }

        // overlapping visits with different/unconfirmed places
        if consumerVisit.overlaps(consumeeVisit) {

            // consumer has confirmed place, consumee doesn't
            if consumerVisit.hasConfirmedPlace && !consumeeVisit.hasConfirmedPlace {
                return .perfect // consumer wins
            }

            // consumee has confirmed place, consumer doesn't
            if !consumerVisit.hasConfirmedPlace && consumeeVisit.hasConfirmedPlace {
                return .impossible // no merge
            }

            // neither have confirmed places - the longer duration wins
            return consumerRange.duration > consumeeRange.duration ? .perfect : .high
        }
        
        return .impossible
    }
    
    // MARK: - VISIT <- TRIP
    private static func consumptionScoreFor(visit consumer: TimelineItem, toConsumeTrip consumee: TimelineItem) -> ConsumptionScore {
        guard consumer.isVisit, consumee.isTrip else { fatalError() }
        guard let consumerVisit = consumer.visit else { return .impossible }

        do {
            let pctInside = try consumee.percentInside(consumerVisit)
            let pctInsideScore = Int(floor(pctInside * 10))

            // valid / keeper visit <- invalid trip
            if try consumer.isValid && consumee.isInvalid {
                switch pctInsideScore {
                case 10: // 100%
                    return .low
                default:
                    return .veryLow
                }
            }

            return .impossible

        } catch {
            logger.error(error, subsystem: .timeline)
            return .impossible
        }
    }

}
