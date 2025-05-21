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
            // Create visit specific data with empty samples array
            guard let visit = TimelineItemVisit(itemId: legacyItem.itemId, samples: []) else {
                throw TimelineError.invalidItem("Could not create visit component")
            }
            
            // Set visit properties if available
            var mutableVisit = visit
            
            if let placeId = legacyItem.placeId {
                mutableVisit.placeId = placeId
                mutableVisit.confirmedPlace = legacyItem.manualPlace ?? false
            }
            
            if let streetAddress = legacyItem.streetAddress {
                mutableVisit.streetAddress = streetAddress
            }
            
            if let customTitle = legacyItem.customTitle {
                mutableVisit.customTitle = customTitle
            }
            
            // Set default coordinates for the visit
            // For now, just use (0,0) as a placeholder - real coordinates will come from samples
            mutableVisit.latitude = 0
            mutableVisit.longitude = 0
            
            // Default radius values - will be updated from samples later
            mutableVisit.radiusMean = 30
            mutableVisit.radiusSD = 10
            
            self.visit = mutableVisit
            
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
                }
            }
            
            self.trip = trip
        }
    }
}
