//
//  ActivityBrain.swift
//  
//
//  Created by Matt Greenfield on 26/2/24.
//

import Foundation
import CoreLocation

class ActivityBrain {

    let newKalman = KalmanFilter()
    let oldKalman = KalmanCoordinates(qMetresPerSecond: 4)

    func add(location: CLLocation) {
        newKalman.add(location: location)
        oldKalman.add(location: location)
    }

}
