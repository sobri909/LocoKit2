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
    case hotAirBalloon = 35

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
        case .unknown:
            return String(localized: "unknown", bundle: .module)
        case .bogus:
            return String(localized: "bogus", bundle: .module)
        case .stationary:
            return String(localized: "stationary", bundle: .module)
        case .walking:
            return String(localized: "walking", bundle: .module)
        case .running:
            return String(localized: "running", bundle: .module)
        case .cycling:
            return String(localized: "cycling", bundle: .module)
        case .car:
            return String(localized: "car", bundle: .module)
        case .airplane:
            return String(localized: "airplane", bundle: .module)
        case .train:
            return String(localized: "train", bundle: .module)
        case .bus:
            return String(localized: "bus", bundle: .module)
        case .motorcycle:
            return String(localized: "motorcycle", bundle: .module)
        case .boat:
            return String(localized: "boat", bundle: .module)
        case .tram:
            return String(localized: "tram", bundle: .module)
        case .tractor:
            return String(localized: "tractor", bundle: .module)
        case .tuktuk:
            return String(localized: "tuk-tuk", bundle: .module)
        case .songthaew:
            return String(localized: "songthaew", bundle: .module)
        case .scooter:
            return String(localized: "scooter", bundle: .module)
        case .metro:
            return String(localized: "metro", bundle: .module)
        case .cableCar:
            return String(localized: "cable car", bundle: .module)
        case .funicular:
            return String(localized: "funicular", bundle: .module)
        case .chairlift:
            return String(localized: "chairlift", bundle: .module)
        case .skiLift:
            return String(localized: "ski lift", bundle: .module)
        case .taxi:
            return String(localized: "taxi", bundle: .module)
        case .hotAirBalloon:
            return String(localized: "hot air balloon", bundle: .module)
        case .skateboarding:
            return String(localized: "skateboarding", bundle: .module)
        case .inlineSkating:
            return String(localized: "inline skating", bundle: .module)
        case .snowboarding:
            return String(localized: "snowboarding", bundle: .module)
        case .skiing:
            return String(localized: "skiing", bundle: .module)
        case .horseback:
            return String(localized: "horseback", bundle: .module)
        case .swimming:
            return String(localized: "swimming", bundle: .module)
        case .golf:
            return String(localized: "golf", bundle: .module)
        case .wheelchair:
            return String(localized: "wheelchair", bundle: .module)
        case .rowing:
            return String(localized: "rowing", bundle: .module)
        case .kayaking:
            return String(localized: "kayaking", bundle: .module)
        case .surfing:
            return String(localized: "surfing", bundle: .module)
        case .hiking:
            return String(localized: "hiking", bundle: .module)
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
        case "hotAirBalloon": self = .hotAirBalloon
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
        .taxi, .hotAirBalloon, .swimming, .golf, .wheelchair, .rowing, .kayaking, .surfing, .hiking, .bogus
    ]

    public static let nonMovingTypes: [ActivityType] = [.stationary, .bogus, .unknown]

    public static var movingTypes: [ActivityType] {
        allCases.filter(\.isMovingType)
    }

    // activity types that can sensibly have related step counts
    public static let stepsTypes: [ActivityType] = [
        .walking, .running, .cycling, .golf, .rowing, .kayaking, .hiking
    ]

    public static let workoutTypes: [ActivityType] = [
        .walking, .running, .cycling, .skateboarding, .inlineSkating, .skiing, .snowboarding, .horseback, .hiking, .surfing, .swimming, .rowing, .kayaking, .golf, .wheelchair
    ]

}
