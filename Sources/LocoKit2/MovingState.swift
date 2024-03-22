//
//  MovingState.swift
//  
//
//  Created by Matt Greenfield on 6/3/24.
//

import Foundation
import CoreLocation

public enum MovingState: Int, Codable {
    case uncertain  = -1
    case stationary = 0
    case moving     = 1

    public var stringValue: String {
        switch self {
        case .uncertain:  return "uncertain"
        case .stationary: return "stationary"
        case .moving:     return "moving"
        }
    }
}

public struct MovingStateDetails {
    public let movingState: MovingState
    public let n: Int
    public let timestamp: Date
    public let meanAccuracy: CLLocationAccuracy?
    public let meanSpeed: CLLocationSpeed?
    public let sdSpeed: CLLocationSpeed?

    internal init(
        _ movingState: MovingState,
        n: Int, timestamp: Date,
        meanAccuracy: CLLocationAccuracy? = nil,
        meanSpeed: CLLocationSpeed? = nil,
        sdSpeed: CLLocationSpeed? = nil
    ) {
        self.movingState = movingState
        self.n = n
        self.timestamp = timestamp
        self.meanAccuracy = meanAccuracy
        self.meanSpeed = meanSpeed
        self.sdSpeed = sdSpeed
    }
}
