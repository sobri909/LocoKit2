//
//  Extensions.swift
//
//
//  Created by Matt Greenfield on 27/2/24.
//

import Foundation
import CoreLocation

extension CLLocationDirection {
    var radians: Double { self * .pi / 180.0 }
}
