//
//  ActivityType.swift
//
//  Created by Matt Greenfield on 12/10/17.
//

public enum ActivityType: String, CaseIterable, Codable, Sendable {

    // special types
    case unknown
    case bogus

    // base types
    case stationary
    case walking
    case running
    case cycling
    case car
    case airplane

    // transport types
    case train
    case bus
    case motorcycle
    case boat
    case tram
    case tractor
    case tuktuk
    case songthaew
    case scooter
    case metro
    case cableCar
    case funicular
    case chairlift
    case skiLift
    case taxi

    // active types
    case skateboarding
    case inlineSkating
    case snowboarding
    case skiing
    case horseback
    case swimming
    case golf
    case wheelchair
    case rowing
    case kayaking
    case surfing
    case hiking

    public var displayName: String {
        switch self {
        case .tuktuk:
            return "tuk-tuk"
        case .inlineSkating:
            return "inline skating"
        case .cableCar:
            return "cable car"
        case .skiLift:
            return "ski lift"
        default:
            return rawValue
        }
    }

    // MARK: -

    public static let baseTypes = [stationary, walking, running, cycling, car, airplane]

    public static let extendedTypes = [
        train, bus, motorcycle, boat, tram, tractor, tuktuk, songthaew, skateboarding, inlineSkating, snowboarding, skiing, horseback,
        scooter, metro, cableCar, funicular, chairlift, skiLift, taxi, swimming, golf, wheelchair, rowing, kayaking, surfing, hiking, bogus
    ]

    // activity types that can sensibly have related step counts
    public static let stepsTypes = [walking, running, cycling, golf, rowing, kayaking, hiking]

}
