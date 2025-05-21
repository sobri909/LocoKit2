//
//  LocomotionSample+Legacy.swift
//  LocoKit2
//
//  Created on 2025-05-20
//

import Foundation
import CoreLocation

extension LocomotionSample {
    init(from legacySample: LegacySample) {
        self.init(
            id: legacySample.sampleId, date: legacySample.date,
            secondsFromGMT: legacySample.secondsFromGMT ?? TimeZone.current.secondsFromGMT(),
            movingState: MovingState(stringValue: legacySample.movingState) ?? .uncertain,
            recordingState: RecordingState(stringValue: legacySample.recordingState) ?? .off,
            location: legacySample.location
        )
        
        // Assign timeline item reference
        self.timelineItemId = legacySample.timelineItemId
        
        // Copy motion data if available
        self.stepHz = legacySample.stepHz
        self.xyAcceleration = legacySample.xyAcceleration
        self.zAcceleration = legacySample.zAcceleration
        
        // Preserve source field
        self.source = legacySample.source
        
        // Map disabled field from legacy sample
        // Only import non-deleted samples when calling this initializer
        self.disabled = legacySample.disabled
        
        // Map activity types
        if let classifiedType = legacySample.classifiedType {
            self.classifiedActivityType = ActivityType(stringValue: classifiedType)
        }
        
        if let confirmedType = legacySample.confirmedType {
            self.confirmedActivityType = ActivityType(stringValue: confirmedType)
        }
    }
}
