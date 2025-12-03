# LocoKit2 Export Format Specification

## Version
- Current schema version: 2.2.0
- Uses semantic versioning (major.minor.patch)
- Major version changes indicate breaking format changes
- Minor versions add features in a backward-compatible way
- Patch versions make backward-compatible fixes

### Version History
- **2.2.0**: Added gzip compression for sample files (samples/*.json.gz)
- **2.1.0**: Changed date encoding from numeric (seconds since reference date) to ISO8601 strings
- **2.0.0**: Initial LocoKit2 export format

## Export Formats

Two supported export formats with different use cases:

### 1. Bucketed Format

Designed for full database backups and incremental updates. Files grouped by type and time period for efficient storage and updates.

#### Directory Structure
```
export-YYYY-MM-DD-HHmmss/
  metadata.json
  places/
    0.json   # Places with UUIDs starting "0"
    1.json   # Places with UUIDs starting "1"
    .../     # Through "9", then "A" through "F" (16 buckets total)
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
  "schemaVersion": "2.1.0",     // Semantic version of export format
  "exportMode": "bucketed",     // "bucketed" or "singleFile"
  "exportType": "full",         // "full" or "incremental"

  // Export session timing (ISO8601 strings)
  "sessionStartDate": "2025-12-02T10:30:00Z",   // When this export session began
  "sessionFinishDate": "2025-12-02T10:32:45Z",  // When session completed

  // For incremental backups
  "lastBackupDate": "2025-12-02T10:30:00Z",     // Timestamp for next incremental query
  "backupProgressDate": null,                   // Catch-up progress (nil when complete)

  // Session completion status
  "itemsCompleted": true,   // All qualifying items were exported
  "placesCompleted": true,  // All qualifying places were exported
  "samplesCompleted": true, // All qualifying samples were exported

  "stats": {
    "placeCount": 5640,    // Total places in this export
    "itemCount": 38308,    // Total timeline items in this export
    "sampleCount": 6989051 // Total samples in this export
  },

  // Optional: extension state for app-specific tables
  "extensions": {
    "notes": { "recordCount": 142 }
  }
}
```

### 2. Single File Format (Planned)

Designed for sharing specific date ranges. All data contained in one file. Not yet implemented.

#### File Structure
```
2025-01-05.json[.gz]   # Contents:
{
  "schemaVersion": "2.1.0",
  "exportMode": "singleFile",
  "exportType": "partial",
  "exportRange": {
    "start": "2025-01-05T00:00:00Z",
    "end": "2025-01-06T00:00:00Z"
  },
  "sessionStartDate": "2025-12-02T10:30:00Z",
  "sessionFinishDate": "2025-12-02T10:32:45Z",
  "itemsCompleted": true,
  "placesCompleted": true,
  "samplesCompleted": true,
  "stats": {
    "placeCount": 42,
    "itemCount": 96,
    "sampleCount": 1440
  },
  "items": [...],
  "places": [...],
  "samples": [...]
}
```

## Export Policy

### Completeness Philosophy

The export system follows these data preservation principles:

1. **All Places**: Every Place is included in exports, regardless of visitCount or usage status
   - Ensures referential integrity for TimelineItemVisit records
   - Preserves all place data, even for places that may be used in the future
   - Maintains consistent place identifiers across exports

2. **All TimelineItems**: Every TimelineItem is included, including those marked as deleted
   - Preserves complete timeline history
   - Maintains referential integrity for Samples
   - Follows the philosophy that "samples are the purest most essential part of the database and should never be lost"

3. **All Samples**: Every Sample is included, preserving the raw timeline data
   - Captures complete movement history
   - Enables future reprocessing or analysis
   - Maintains the highest level of data fidelity

This approach ensures that exports contain the complete dataset needed for full restoration, and that referential integrity can be maintained during import operations.

## Incremental Updates

The bucketed format supports incremental backups using the `lastBackupDate` field in metadata.json.

### How It Works

1. Query records where `lastSaved > lastBackupDate` (bounded by session start time)
2. For each bucket with changes, rewrite the entire bucket file
3. On successful completion, update `lastBackupDate` to this session's start time

### Bounded Snapshot

Incremental exports use a bounded time window:
- Lower bound: `lastBackupDate` from previous backup (or nil for first run)
- Upper bound: session start time (prevents "chasing" incoming data)

This ensures clean backup windows with no missed or duplicate data.

### Catch-Up Mode

For first-run backups with large datasets, the system uses catch-up mode:
- Exports samples in 6-month chunks to stay within iOS background task limits
- `backupProgressDate` tracks how far catch-up has progressed
- Loops through chunks until complete or task is cancelled
- Once caught up, `lastBackupDate` is set and `backupProgressDate` cleared

### Cancellation Handling

If a backup is cancelled before completion:
- `lastBackupDate` is NOT updated (or `backupProgressDate` preserves catch-up progress)
- Next run resumes from where it left off
- Re-checking already-backed-up buckets is cheap (query returns empty)

Session completion flags (`itemsCompleted`, etc) indicate whether all qualifying objects were successfully exported during that session.

## Data Types

### Place
```typescript
{
  id: string           // UUID
  name: string        // Required, non-null
  streetAddress: string | null
  locality: string | null
  countryCode: string | null
  secondsFromGMT: number
  latitude: number
  longitude: number
  radiusMean: number  // meters
  radiusSD: number    // standard deviation in meters
  isStale: boolean
  visitCount: number
  visitDays: number
  lastSaved: string   // ISO8601 date string
  source: string      // eg "LocoKit2"
  rtreeId: number | null

  // Provider IDs
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
    startDate: string       // ISO8601 date string
    endDate: string         // ISO8601 date string
    source: string
    sourceVersion: string
    disabled: boolean
    deleted: boolean
    lastSaved: string       // ISO8601 date string
    previousItemId: string | null
    nextItemId: string | null
    samplesChanged: boolean
    locked: boolean

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
    itemId: string           // UUID, foreign key to base
    latitude: number
    longitude: number
    radiusMean: number
    radiusSD: number
    placeId: string | null
    confirmedPlace: boolean
    uncertainPlace: boolean
    lastSaved: string        // ISO8601 date string
  }
}
```

#### TimelineItemTrip
Additional fields for trip items:
```typescript
{
  trip: {
    itemId: string           // UUID, foreign key to base
    distance: number
    speed: number
    classifiedActivityType: number | null
    confirmedActivityType: number | null
    uncertainActivityType: boolean
    lastSaved: string        // ISO8601 date string
  }
}
```

### LocomotionSample
```typescript
{
  id: string                // UUID
  date: string             // ISO8601 date string
  source: string
  sourceVersion: string
  secondsFromGMT: number
  movingState: number      // Maps to MovingState enum
  recordingState: number   // Maps to RecordingState enum
  disabled: boolean
  lastSaved: string        // ISO8601 date string
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

### Date Encoding
- All dates use ISO8601 format (eg "2025-12-02T10:30:00Z")
- Import decoder also handles legacy numeric formats for backwards compatibility:
  - Apple reference date (seconds since 2001-01-01) - detected by magnitude < 978307200
  - Unix timestamp (seconds since 1970-01-01) - detected by magnitude >= 978307200
- Timezone offsets (secondsFromGMT) stored separately for local time reconstruction

### General
- UUIDs are string format without curly braces
- Empty/null fields may be omitted from JSON
- Sample files use gzip compression (.json.gz), compatible with standard gunzip/zcat tools
- Import supports both compressed (.json.gz) and uncompressed (.json) sample files for backwards compatibility
- Week numbers use ISO week date system, UTC-based
- Week files use YYYY-Www format (eg "2025-W01")
- Place buckets use first character of UUID (0-9, A-F)