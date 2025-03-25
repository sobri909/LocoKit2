//
//  CoreMLFeatureProvider.swift
//  Arc
//
//  Created by Matt Greenfield on 1/9/22.
//  Copyright © 2022 Big Paua. All rights reserved.
//

import CoreML
import CoreLocation

class CoreMLFeatureProvider: MLFeatureProvider {

    var stepHz: Double?
    var xyAcceleration: Double?
    var zAcceleration: Double?
    var movingState: Int
    var verticalAccuracy: Double?
    var horizontalAccuracy: Double?
    var speed: Double?
    var course: Double?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var heartRate: Double?
    var timeOfDay: Double
    var sinceVisitStart: Double

    var featureNames: Set<String> {
        get {
            return [
                "stepHz", "xyAcceleration", "zAcceleration", "movingState",
                "verticalAccuracy", "horizontalAccuracy",
                "speed", "course",
                "latitude", "longitude", "altitude", "heartRate",
                "timeOfDay", "sinceVisitStart"
            ]
        }
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "stepHz") {
            return MLFeatureValue(double: stepHz ?? -1)
        }
        if (featureName == "xyAcceleration") {
            return MLFeatureValue(double: xyAcceleration ?? -1)
        }
        if (featureName == "zAcceleration") {
            return MLFeatureValue(double: zAcceleration ?? -1)
        }
        if (featureName == "movingState") {
            return MLFeatureValue(int64: Int64(movingState))
        }
        if (featureName == "verticalAccuracy") {
            return MLFeatureValue(double: verticalAccuracy ?? -1)
        }
        if (featureName == "horizontalAccuracy") {
            return MLFeatureValue(double: horizontalAccuracy ?? -1)
        }
        if (featureName == "speed") {
            return MLFeatureValue(double: speed ?? -1)
        }
        if (featureName == "course") {
            return MLFeatureValue(double: course ?? -1)
        }
        if (featureName == "latitude") {
            return MLFeatureValue(double: latitude ?? kCLLocationCoordinate2DInvalid.latitude)
        }
        if (featureName == "longitude") {
            return MLFeatureValue(double: longitude ?? kCLLocationCoordinate2DInvalid.longitude)
        }
        if (featureName == "altitude") {
            return MLFeatureValue(double: altitude ?? 0)
        }
        if (featureName == "heartRate") {
            return MLFeatureValue(double: heartRate ?? -1)
        }
        if (featureName == "timeOfDay") {
            return MLFeatureValue(double: timeOfDay)
        }
        if (featureName == "sinceVisitStart") {
            return MLFeatureValue(double: sinceVisitStart)
        }
        return nil
    }

    init(
        stepHz: Double?, xyAcceleration: Double?, zAcceleration: Double?, movingState: Int,
        verticalAccuracy: Double?, horizontalAccuracy: Double?,
        speed: Double?, course: Double?,
        latitude: Double?, longitude: Double?, altitude: Double?,
        heartRate: Double? = nil,
        timeOfDay: Double, sinceVisitStart: Double
    ) {
        self.stepHz = stepHz
        self.xyAcceleration = xyAcceleration
        self.zAcceleration = zAcceleration
        self.movingState = movingState
        self.verticalAccuracy = verticalAccuracy
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.heartRate = heartRate
        self.timeOfDay = timeOfDay
        self.sinceVisitStart = sinceVisitStart
    }

}
