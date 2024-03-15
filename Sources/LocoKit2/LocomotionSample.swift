//
//  LocomotionSample.swift
//
//
//  Created by Matt Greenfield on 13/3/24.
//

import Foundation
import CoreLocation
import GRDB

public struct LocomotionSample: Identifiable, Decodable, FetchableRecord {
    public var base: SampleBase
    public var location: SampleLocation?
    public var extended: SampleExtended?

    public var id: String { base.id }
    public var clLocation: CLLocation? { location?.clLocation }
}

