//
//  Place+Comparisons.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 28/12/2024.
//

import Foundation
import CoreLocation

extension Place {
    public func contains(_ location: CLLocation, sd: Double) -> Bool {
        return location.distance(from: center.location) <= radius.withSD(sd)
    }

    public func overlaps(_ visit: TimelineItemVisit) -> Bool {
        guard let dist = distance(from: visit) else { return false }
        return dist < 0
    }

    public func overlaps(_ segment: ItemSegment) -> Bool {
        if let distance = distance(from: segment) {
            return distance < 0
        }
        return false
    }

    public func overlaps(center: CLLocationCoordinate2D, radius: Radius) -> Bool {
        return distance(from: center, radius: radius) < 0
    }

    public func overlaps(_ otherPlace: Place) -> Bool {
        return distance(from: otherPlace) < 0
    }

    // TODO: Arc Timeline uses 4sd if visitCount is < 2
    public func distance(from visit: TimelineItemVisit) -> CLLocationDistance? {
        guard let visitCenter = visit.center else { return nil }
        return center.location.distance(from: visitCenter.location) - radius.with3sd - visit.radius.with1sd
    }

    public func distance(from segment: ItemSegment) -> CLLocationDistance? {
        guard let segmentCenter = segment.center, let segmentRadius = segment.radius else { return nil }
        return distance(from: segmentCenter, radius: segmentRadius)
    }

    public func distance(from center: CLLocationCoordinate2D, radius: Radius) -> CLLocationDistance {
        return self.center.location.distance(from: center.location) - self.radius.with3sd - radius.with2sd
    }

    public func distance(from otherPlace: Place) -> CLLocationDistance {
        return center.location.distance(from: otherPlace.center.location) - radius.with3sd - otherPlace.radius.with3sd
    }
}
