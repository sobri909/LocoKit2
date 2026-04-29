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

One implemented format, with a second planned:

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
  "exportId": "A1B2C3D4-...",   // Unique identifier for this export session (used for resume validation)
  "schemaVersion": "2.2.0",     // Semantic version of export format
  "exportMode": "bucketed",     // "bucketed" (only supported mode currently)
  "exportType": "full",         // "full" or "incremental" (only valid values)

  // Export session timing (ISO8601 strings)
  "sessionStartDate": "2025-12-02T10:30:00Z",   // When this export session began
  "sessionFinishDate": "2025-12-02T10:32:45Z",  // When session completed (null while in flight or if never finalized)

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
  },

  // Optional: app-specific metadata (passthrough from app layer)
  "appMetadata": {
    "key": "value"
  }
}
```

**Important**: The `exportType` field only accepts `"full"` or `"incremental"`. Other values (e.g. `"partial"`, `"backup"`) will cause a decode failure during import.

### 2. Single File Format (Planned)

Designed for sharing specific date ranges. All data contained in one file. **Not yet implemented.**

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
  name: string        // Required, non-null, must be non-empty
  streetAddress: string | null
  locality: string | null
  countryCode: string | null
  secondsFromGMT: number | null  // nullable (pre-2019 data may lack timezone)
  latitude: number
  longitude: number
  radiusMean: number  // meters
  radiusSD: number    // standard deviation in meters
  isStale: boolean
  visitCount: number
  visitDays: number
  lastVisitDate: string | null  // ISO8601 date string
  lastSaved: string   // ISO8601 date string
  source: string      // eg "LocoKit2"
  rtreeId: number | null

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

Note: Place histogram data (arrivalTimes, leavingTimes, visitDurations, occupancyTimes) is stored in the database as binary blobs but is **not included** in JSON exports. These are regenerated from visit data.

### TimelineItem Structure
Timeline items are stored in three related tables that form a hierarchy. In exports they are emitted as a single wrapper object with the sub-records nested under fixed keys:

```json
{
  "base":  { ... },          // always present
  "visit": { ... },          // present iff base.isVisit == true
  "trip":  { ... },          // present iff base.isVisit == false
  "place": { ... },          // optional embedded Place (see below)
  "samples": [ ... ]         // optional embedded LocomotionSamples (see below)
}
```

`items/YYYY-MM.json[.gz]` files in the bucketed format contain an array of these wrappers, with `place` and `samples` omitted — places live in their own `places/` bucket files and samples live in their own `samples/` week files. The single-file format (planned) is expected to use the same wrapper shape but with `place` and `samples` populated inline so that an item is self-contained.

Exactly one of `visit` or `trip` is present per item. The discriminator is `base.isVisit`: `true` ⇒ `visit` block present, `false` ⇒ `trip` block present.

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
    latitude: number | null  // nullable (both must be null or both valid)
    longitude: number | null // nullable (both must be null or both valid)
    radiusMean: number
    radiusSD: number
    placeId: string | null
    confirmedPlace: boolean
    uncertainPlace: boolean
    customTitle: string | null   // user-set custom name for the visit
    streetAddress: string | null
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
  secondsFromGMT: number | null  // nullable (pre-2019 samples may lack timezone)
  movingState: number      // Maps to MovingState enum
  recordingState: number   // Maps to RecordingState enum
  disabled: boolean
  lastSaved: string        // ISO8601 date string
  rtreeId: number | null   // spatial index reference
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
  
  // Health data
  heartRate: number | null
  
  // Activity classification (ActivityType raw value, see Enum Values below)
  classifiedActivityType: number | null
  confirmedActivityType: number | null
}
```

## Enum Values

Several integer-valued fields in the export map to Swift enums. The tables below list the raw values currently in use.

### MovingState

Used by: `LocomotionSample.movingState`. Source: [Sources/LocoKit2/Models/MovingState.swift](../../Sources/LocoKit2/Models/MovingState.swift).

| Raw | Case          |
| --- | ------------- |
| -1  | `uncertain`   |
| 0   | `stationary`  |
| 1   | `moving`      |

### RecordingState

Used by: `LocomotionSample.recordingState`. Source: [Sources/LocoKit2/Models/RecordingState.swift](../../Sources/LocoKit2/Models/RecordingState.swift).

| Raw | Case           |
| --- | -------------- |
| 0   | `off`          |
| 1   | `recording`    |
| 2   | `sleeping`     |
| 3   | `deepSleeping` |
| 4   | `wakeup`       |
| 5   | `standby`      |

### ActivityType

Used by: `LocomotionSample.classifiedActivityType`, `LocomotionSample.confirmedActivityType`, `TimelineItemTrip.classifiedActivityType`, `TimelineItemTrip.confirmedActivityType`. Source: [Sources/LocoKit2/ActivityTypes/ActivityType.swift](../../Sources/LocoKit2/ActivityTypes/ActivityType.swift).

Special:

| Raw | Case        |
| --- | ----------- |
| -1  | `unknown`   |
| 0   | `bogus`     |

Base types:

| Raw | Case          |
| --- | ------------- |
| 1   | `stationary`  |
| 2   | `walking`     |
| 3   | `running`     |
| 4   | `cycling`     |
| 5   | `car`         |
| 6   | `airplane`    |

Transport types:

| Raw | Case            |
| --- | --------------- |
| 20  | `train`         |
| 21  | `bus`           |
| 22  | `motorcycle`    |
| 23  | `boat`          |
| 24  | `tram`          |
| 25  | `tractor`       |
| 26  | `tuktuk`        |
| 27  | `songthaew`     |
| 28  | `scooter`       |
| 29  | `metro`         |
| 30  | `cableCar`      |
| 31  | `funicular`     |
| 32  | `chairlift`     |
| 33  | `skiLift`       |
| 34  | `taxi`          |
| 35  | `hotAirBalloon` |

Active types:

| Raw | Case            |
| --- | --------------- |
| 50  | `skateboarding` |
| 51  | `inlineSkating` |
| 52  | `snowboarding`  |
| 53  | `skiing`        |
| 54  | `horseback`     |
| 55  | `swimming`      |
| 56  | `golf`          |
| 57  | `wheelchair`    |
| 58  | `rowing`        |
| 59  | `kayaking`      |
| 60  | `surfing`       |
| 61  | `hiking`        |

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