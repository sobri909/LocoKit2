//
//  RecordingState.swift
//
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation

public enum RecordingState: String, Codable {
    case recording, sleeping, deepSleeping, wakeup, standby, off

    public static let sleepStates = [sleeping, deepSleeping]

}
