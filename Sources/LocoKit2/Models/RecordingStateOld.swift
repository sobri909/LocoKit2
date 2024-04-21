//
//  RecordingStateOld.swift
//  LocoKit
//
//  Created by Matt Greenfield on 26/11/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

/**
 The recording state of the LocomotionManager.
 */
public enum RecordingStateOld: String, Codable {
    case recording
    case sleeping
    case deepSleeping
    case wakeup
    case standby
    case off

    public var isSleeping: Bool { return RecordingStateOld.sleepStates.contains(self) }
    public var isCurrentRecorder: Bool { return RecordingStateOld.activeRecorderStates.contains(self) }

    public static let sleepStates = [wakeup, sleeping, deepSleeping]
    public static let activeRecorderStates = [recording, wakeup, sleeping, deepSleeping]

    init?(intValue: Int) {
        guard let newState = RecordingState(rawValue: intValue) else { return nil }
        self.init(rawValue: newState.stringValue)
    }
}
