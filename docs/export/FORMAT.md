# LocoKit2 Export Format Specification

## Version
- Current schema version: 1.0.0
- Uses semantic versioning (major.minor.patch)
- Major version changes indicate breaking format changes
- Minor versions add features in a backward-compatible way
- Patch versions make backward-compatible fixes

## Export Formats

Two supported export formats with different use cases:

### 1. Bucketed/Compressed Format

Designed for full database backups and large datasets. Files grouped by type and time period to enable efficient incremental backups and future data merging.

#### Directory Structure
```
export-YYYY-MM-DD-HHmmss/
  metadata.json
  places/
    0.json[.gz]   # Places with UUIDs starting "0" (e.g. "01ABCDEF-...")
    1.json[.gz]   # Places with UUIDs starting "1" (e.g. "12BCDEF0-...")
    .../          # Through "F"
  items/
    2025-01.json[.gz]   # Timeline items for January 2025
    2025-02.json[.gz]   # Timeline items for February 2025
    ...
  samples/
    2025-W01.json[.gz]  # Location samples for week 1, 2025
    2025-W02.json[.gz]  # Location samples for week 2, 2025
    ...
```

#### File Formats

metadata.json:
```json
{
  "metadata": {
    "schemaVersion": "1.0.0",
    "exportMode": "bucketed",
    "exportDate": "2025-01-10T13:45:00Z",
    "exportCompleted": true,
    "stats": {
      "placeCount": 5640,
      "itemCount": 38308,
      "sampleCount": 6989051
    }
  }
}
```

### 2. Single File Format

Designed for data analysis and sharing specific date ranges. All data contained in one file.

#### File Structure
```
2025-01-05.json[.gz]   # Contents:
{
  "metadata": {
    "schemaVersion": "1.0.0",
    "exportMode": "singleFile",
    "dateRange": {
      "start": "2025-01-05T00:00:00Z",
      "end": "2025-01-05T23:59:59Z"
    },
    "exportCompleted": true
  },
  "items": [...],
  "places": [...],
  "samples": [...]
}
```

## Data Types

### Place
```typescript
{
  id: string           // UUID
  name: string        // Required, non-null
  streetAddress: string | null
  secondsFromGMT: number
  latitude: number
  longitude: number
  radiusMean: number  // meters
  radiusSD: number    // standard deviation in meters
  isStale: boolean
  visitCount: number
  visitDays: number
  lastSaved: string   // ISO8601 datetime with timezone
  
  // Provider IDs
  mapboxPlaceId: string | null
  mapboxCategory: string | null
  mapboxMakiIcon: string | null
  googlePlaceId: string | null
  googlePrimaryType: string | null
  foursquarePlaceId: string | null
  foursquareCategoryId: number | null
}
```

### TimelineItem Structure
Timeline items are stored in three related tables that form a hierarchy:

#### TimelineItemBase
Base fields common to all timeline items:
```typescript
{
  base: {
    id: string               // UUID
    isVisit: boolean        // Type discriminator
    startDate: string       // ISO8601 datetime
    endDate: string         // ISO8601 datetime
    source: string
    sourceVersion: string
    disabled: boolean
    deleted: boolean
    lastSaved: string       // ISO8601 datetime with timezone
    previousItemId: string | null
    nextItemId: string | null
    
    // HealthKit stats
    stepCount: number | null
    floorsAscended: number | null
    floorsDescended: number | null 
    averageAltitude: number | null
    activeEnergyBurned: number | null
    averageHeartRate: number | null
    maxHeartRate: number | null
  }
}
```

#### TimelineItemVisit
Additional fields for visit items:
```typescript
{
  visit: {
    latitude: number
    longitude: number
    radiusMean: number
    radiusSD: number
    placeId: string | null
    confirmedPlace: boolean
    uncertainPlace: boolean
    customTitle: string | null
    streetAddress: string | null
  }
}
```

#### TimelineItemTrip
Additional fields for trip items:
```typescript
{
  trip: {
    distance: number
    speed: number
    classifiedActivityType: number | null
    confirmedActivityType: number | null
    uncertainActivityType: boolean
  }
}
```

### LocomotionSample
```typescript
{
  id: string                // UUID
  date: string             // ISO8601 datetime
  source: string
  sourceVersion: string
  secondsFromGMT: number
  movingState: number      // Maps to MovingState enum
  recordingState: number   // Maps to RecordingState enum
  disabled: boolean
  lastSaved: string        // ISO8601 datetime with timezone
  timelineItemId: string | null
  
  // Location data
  latitude: number | null
  longitude: number | null
  altitude: number | null
  horizontalAccuracy: number | null
  verticalAccuracy: number | null
  speed: number | null
  course: number | null
  
  // Motion data
  stepHz: number | null
  xyAcceleration: number | null
  zAcceleration: number | null
  
  // Activity classification
  classifiedActivityType: number | null
  confirmedActivityType: number | null
}
```

## Notes

- All dates use UTC timezone internally
- Timezone offsets (secondsFromGMT) stored separately
- UUIDs are string format without curly braces
- Empty/null fields should be omitted from JSON
- Files can optionally be gzipped (indicated by .gz extension)
- Week numbers use ISO week date system for UTC
- Incremental updates supported through lastSaved timestamps
- Single file exports include all samples for included items
- Items included based on UTC overlap with export timeframe