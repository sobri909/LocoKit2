//
//  TimelineItem+Legacy.swift
//
//
//  Created on 2025-05-20.
//

import Foundation
import CoreLocation

extension TimelineItem {
    
    init(from legacyItem: LegacyItem) throws {
        // Create base item with isVisit property
        let base = TimelineItemBase(isVisit: legacyItem.isVisit)
        
        // Set core properties
        var mutableBase = base
        mutableBase.id = legacyItem.itemId
        mutableBase.source = legacyItem.source
        mutableBase.deleted = legacyItem.deleted
        mutableBase.disabled = legacyItem.disabled
        mutableBase.previousItemId = legacyItem.previousItemId
        mutableBase.nextItemId = legacyItem.nextItemId
        
        // Set health data if available
        if let activeEnergyBurned = legacyItem.activeEnergyBurned {
            mutableBase.activeEnergyBurned = activeEnergyBurned
        }
        if let averageHeartRate = legacyItem.averageHeartRate {
            mutableBase.averageHeartRate = averageHeartRate
        }
        if let maxHeartRate = legacyItem.maxHeartRate {
            mutableBase.maxHeartRate = maxHeartRate
        }
        
        // Import step count data (could be from pedometer or HealthKit)
        if let stepCount = legacyItem.hkStepCount, stepCount.isFinite {
            // Clamp to reasonable range for step counts
            let clampedValue = max(0, min(stepCount, 1_000_000)) // 1M steps max seems reasonable
            mutableBase.stepCount = Int(clampedValue)
        }
        
        // Initialize with proper properties
        self.base = mutableBase
        
        if legacyItem.isVisit {
            var visit = TimelineItemVisit(
                itemId: legacyItem.itemId,
                latitude: legacyItem.latitude,
                longitude: legacyItem.longitude,
                radiusMean: legacyItem.radiusMean ?? 50,
                radiusSD: legacyItem.radiusSD ?? 10
            )
            
            if let placeId = legacyItem.placeId {
                visit.placeId = placeId
                visit.confirmedPlace = legacyItem.manualPlace ?? false
                // set uncertainty based on whether place is confirmed
                visit.setUncertainty(!visit.confirmedPlace)
            } else {
                // no placeId means it must be uncertain
                visit.setUncertainty(true)
            }
            
            visit.streetAddress = legacyItem.streetAddress
            visit.customTitle = legacyItem.customTitle
            
            self.visit = visit
            
        } else {
            // Create trip specific data with empty samples array
            var trip = TimelineItemTrip(itemId: legacyItem.itemId, samples: [])
            
            // Set trip properties if available
            if let distance = legacyItem.distance {
                trip.distance = distance
            }
            
            if let activityType = legacyItem.activityType {
                trip.classifiedActivityType = ActivityType(stringValue: activityType)
                
                if let manualActivityType = legacyItem.manualActivityType, manualActivityType {
                    trip.confirmedActivityType = ActivityType(stringValue: activityType)
                    // if we have a confirmed type, we can't be uncertain
                    trip.uncertainActivityType = false
                } else {
                    // unconfirmed activity type - could be uncertain
                    trip.uncertainActivityType = true
                }
            } else {
                // no activity type at all - must be uncertain
                trip.uncertainActivityType = true
            }
            
            self.trip = trip
        }
    }
}
