//
//  LocomotionSample.swift
//
//
//  Created by Matt Greenfield on 13/3/24.
//

import Foundation
import CoreLocation
import GRDB

struct LocomotionSample: Identifiable, Decodable, FetchableRecord {
    var base: LocomotionSampleBase
    var location: SampleLocation?
    var extended: LocomotionSampleExtended?

    var id: String { base.id }
    var clLocation: CLLocation? { location?.clLocation }
}
