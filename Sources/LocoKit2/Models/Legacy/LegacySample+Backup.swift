//
//  LegacySample+Backup.swift
//  LocoKit2
//
//  Created by Claude on 2026-09-28
//

import Foundation

extension LegacySample {

    /// A backup-file sample as the sqlite-shaped `LegacySample` the AT3 → LocoKit2 converter
    /// takes (BIG-399). The nested `location` is flattened; a null location leaves every
    /// location field nil, which is the shape `LegacySample.location` already handles (its
    /// force-unwraps are safe because the file writes all eight fields or none).
    /// `movingState` / `recordingState` stay strings here; the converter bridges them.
    init(backup sample: LegacyBackup.Sample) {
        self.init(
            sampleId: sample.sampleId,
            date: sample.date,
            secondsFromGMT: sample.secondsFromGMT,
            source: "LocoKit",
            movingState: sample.movingState,
            recordingState: sample.recordingState,
            deleted: sample.isDeleted,
            disabled: sample.isDisabled,
            classifiedType: sample.classifiedType,
            confirmedType: sample.confirmedType,
            timelineItemId: sample.timelineItemId,
            latitude: sample.location?.latitude,
            longitude: sample.location?.longitude,
            altitude: sample.location?.altitude,
            horizontalAccuracy: sample.location?.horizontalAccuracy,
            verticalAccuracy: sample.location?.verticalAccuracy,
            speed: sample.location?.speed,
            course: sample.location?.course,
            stepHz: sample.stepHz,
            xyAcceleration: sample.xyAcceleration,
            zAcceleration: sample.zAcceleration
        )
    }
}
