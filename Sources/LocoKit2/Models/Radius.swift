//
//  Radius.swift
//  
//
//  Created by Matt Greenfield on 20/3/24.
//

import Foundation
import CoreLocation

public struct Radius: Codable {
    public let mean: CLLocationDistance
    public let sd: CLLocationDistance

    public static var zero: Radius { return Radius(mean: 0, sd: 0) }

    public init(mean: CLLocationDistance, sd: CLLocationDistance) {
        self.mean = mean
        self.sd = sd
    }

    public var with0sd: CLLocationDistance { mean }
    public var with1sd: CLLocationDistance { mean + sd }
    public var with2sd: CLLocationDistance { withSD(2) }
    public var with3sd: CLLocationDistance { withSD(3) }

    public func withSD(_ modifier: Double) -> CLLocationDistance { mean + (sd * modifier) }
}
