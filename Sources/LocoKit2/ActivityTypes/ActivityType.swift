//
//  ActivityType.swift
//
//  Created by Matt Greenfield on 12/10/17.
//

public enum ActivityType: Int, CaseIterable, Codable, Hashable, Sendable {

    // MARK: - Special types

    case unknown = -1
    case bogus = 0

    // MARK: - Base types

    case stationary = 1
    case walking = 2
    case running = 3
    case cycling = 4
    case car = 5
    case airplane = 6

    // MARK: - Transport types

    case train = 20
    case bus = 21
    case motorcycle = 22
    case boat = 23
    case tram = 24
    case tractor = 25
    case tuktuk = 26
    case songthaew = 27
    case scooter = 28
    case metro = 29
    case cableCar = 30
    case funicular = 31
    case chairlift = 32
    case skiLift = 33
    case taxi = 34

    // MARK: - Active types

    case skateboarding = 50
    case inlineSkating = 51
    case snowboarding = 52
    case skiing = 53
    case horseback = 54
    case swimming = 55
    case golf = 56
    case wheelchair = 57
    case rowing = 58
    case kayaking = 59
    case surfing = 60
    case hiking = 61

    // MARK: -

    public var isMovingType: Bool {
        !Self.nonMovingTypes.contains(self)
    }

    // MARK: - Display names

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
            return String(describing: self)
        }
    }

    // MARK: - String init

    public init?(stringValue: String) {
        switch stringValue {
        case "unknown": self = .unknown
        case "bogus": self = .bogus
        case "stationary": self = .stationary
        case "walking": self = .walking
        case "running": self = .running
        case "cycling": self = .cycling
        case "car": self = .car
        case "airplane": self = .airplane
        case "train": self = .train
        case "bus": self = .bus
        case "motorcycle": self = .motorcycle
        case "boat": self = .boat
        case "tram": self = .tram
        case "tractor": self = .tractor
        case "tuktuk": self = .tuktuk
        case "songthaew": self = .songthaew
        case "scooter": self = .scooter
        case "metro": self = .metro
        case "cableCar": self = .cableCar
        case "funicular": self = .funicular
        case "chairlift": self = .chairlift
        case "skiLift": self = .skiLift
        case "taxi": self = .taxi
        case "skateboarding": self = .skateboarding
        case "inlineSkating": self = .inlineSkating
        case "snowboarding": self = .snowboarding
        case "skiing": self = .skiing
        case "horseback": self = .horseback
        case "swimming": self = .swimming
        case "golf": self = .golf
        case "wheelchair": self = .wheelchair
        case "rowing": self = .rowing
        case "kayaking": self = .kayaking
        case "surfing": self = .surfing
        case "hiking": self = .hiking
        default: return nil
        }
    }

    // MARK: - Type collections

    public static let baseTypes: [ActivityType] = [
        .stationary, .walking, .running, .cycling, .car, .airplane
    ]

    public static let extendedTypes: [ActivityType] = [
        .train, .bus, .motorcycle, .boat, .tram, .tractor, .tuktuk, .songthaew,
        .skateboarding, .inlineSkating, .snowboarding, .skiing, .horseback,
        .scooter, .metro, .cableCar, .funicular, .chairlift, .skiLift,
        .taxi, .swimming, .golf, .wheelchair, .rowing, .kayaking, .surfing, .hiking, .bogus
    ]

    public static let nonMovingTypes: [ActivityType] = [.stationary, .bogus, .unknown]

    public static var movingTypes: [ActivityType] {
        allCases.filter(\.isMovingType)
    }

    // activity types that can sensibly have related step counts
    public static let stepsTypes: [ActivityType] = [
        .walking, .running, .cycling, .golf, .rowing, .kayaking, .hiking
    ]

}
