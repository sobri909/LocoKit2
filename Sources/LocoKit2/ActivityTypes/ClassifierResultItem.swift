//
//  ClassifierResultItem.swift
//
//  Created by Matt Greenfield on 13/10/17.
//

import Foundation

public enum ClassifierResultScoreGroup: Int {
    case perfect = 5
    case veryGood = 4
    case good = 3
    case bad = 2
    case veryBad = 1
    case terrible = 0
}

public struct ClassifierResultItem: Equatable, Identifiable, Sendable {

    public var id: Int { return activityType.rawValue }
    public let activityType: ActivityType
    public let score: Double
    public let modelAccuracyScore: Double?

    public init(name: ActivityType, score: Double, modelAccuracyScore: Double? = nil) {
        self.activityType = name
        self.score = score
        self.modelAccuracyScore = modelAccuracyScore
    }

    public func normalisedScore(in results: ClassifierResults) -> Double {
        let scoresTotal = results.scoresTotal
        guard scoresTotal > 0 else { return 0 }
        return score / scoresTotal
    }

    public func normalisedScoreGroup(in results: ClassifierResults) -> ClassifierResultScoreGroup {
        let normalisedScore = self.normalisedScore(in: results)
        switch Int(round(normalisedScore * 100)) {
        case 100: return .perfect
        case 80...100: return .veryGood
        case 50...80: return .good
        case 20...50: return .bad
        case 1...20: return .veryBad
        default: return .terrible
        }
    }

    public static func == (lhs: ClassifierResultItem, rhs: ClassifierResultItem) -> Bool {
        return lhs.activityType == rhs.activityType
    }

}
