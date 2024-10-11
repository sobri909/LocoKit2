//
//  TimelineError.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 2024-10-11.
//

import Foundation

public enum TimelineError: Error {
    case samplesNotLoaded
    case itemNotFound
    case invalidItem(String)
    case invalidSegment(String)
}
