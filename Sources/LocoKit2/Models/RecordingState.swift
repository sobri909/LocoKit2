//
//  RecordingState.swift
//
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation

public enum RecordingState: Int, Codable, Sendable {
    case off = 0
    case recording = 1
    case sleeping = 2
    case deepSleeping = 3
    case wakeup = 4
    case standby = 5

    public static let sleepStates = [wakeup, sleeping, deepSleeping]
    public static let activeRecorderStates = [recording, wakeup, sleeping, deepSleeping]

    // MARK: -

    public var isSleeping: Bool { return Self.sleepStates.contains(self) }
    public var isCurrentRecorder: Bool { return Self.activeRecorderStates.contains(self) }

    public var stringValue: String {
        switch self {
        case .off:          return "off"
        case .recording:    return "recording"
        case .sleeping:     return "sleeping"
        case .deepSleeping: return "deepSleeping"
        case .wakeup:       return "wakeup"
        case .standby:      return "standby"
        }
    }

    // MARK: -

    init?(stringValue: String) {
        switch stringValue {
        case "off": self.init(rawValue: 0)
        case "recording": self.init(rawValue: 1)
        case "sleeping": self.init(rawValue: 2)
        case "deepSleeping": self.init(rawValue: 3)
        case "wakeup": self.init(rawValue: 4)
        case "standby": self.init(rawValue: 5)
        default: return nil
        }
    }
}
