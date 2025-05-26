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
        if let stepCount = legacyItem.hkStepCount {
            mutableBase.stepCount = Int(stepCount)
        }
        
        // Initialize with proper properties
        self.base = mutableBase
        
        if legacyItem.isVisit {
            // Create visit with placeholder coordinates - will be updated when samples are imported
            var visit = TimelineItemVisit(
                itemId: legacyItem.itemId,
                latitude: 0,  // null island placeholder
                longitude: 0,  // null island placeholder
                radiusMean: 50,  // reasonable default radius
                radiusSD: 10  // reasonable default SD
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
            
            if let streetAddress = legacyItem.streetAddress {
                visit.streetAddress = streetAddress
            }
            
            if let customTitle = legacyItem.customTitle {
                visit.customTitle = customTitle
            }
            
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
