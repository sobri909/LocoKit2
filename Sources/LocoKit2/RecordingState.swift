//
//  RecordingState.swift
//
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation

public enum RecordingState: String, Codable {
    case recording
    case sleeping
    case deepSleeping
    case wakeup
    case standby
    case off

    public var isSleeping: Bool { RecordingState.sleepStates.contains(self) }
    public var isCurrentRecorder: Bool { RecordingState.activeRecorderStates.contains(self) }

    public static let sleepStates = [wakeup, sleeping, deepSleeping]
    public static let activeRecorderStates = [recording, sleeping, deepSleeping, wakeup]
}
