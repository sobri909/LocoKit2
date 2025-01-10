# LocoKit2 Export Format Specification

## Version
- Current schema version: 1.0.0
- Uses semantic versioning (major.minor.patch)
- Major version changes indicate breaking format changes
- Minor versions add features in a backward-compatible way
- Patch versions make backward-compatible fixes

## Version History
A history of format changes will be maintained here to help third-party developers track compatibility requirements.

### 1.0.0 (Initial Release)
- Initial format specification
- All JSON files gzipped by default
- Introduced both bucketed and single-file formats
- UTC-based week files for samples
- Month-based files for items
- UUID prefix bucketing for places

## Export Formats

Two supported export formats with different use cases:

### 1. Bucketed/Compressed Format

Designed for full database backups and large datasets. Files grouped by type and time period to enable efficient incremental backups and future data merging.

#### Directory Structure
```
export-YYYY-MM-DD-HHmmss/
  metadata.json
  places/
    00.json.gz  # Places with UUIDs starting "00" (e.g. "00ABCDEF-...")
    01.json.gz  # Places with UUIDs starting "01" (e.g. "0123CDEF-...")
    .../        # Through "FF"

  # Places are assigned to buckets based on the first two characters of their UUID.
  # For example, a place with UUID "2A95C320-D04E-4F53-8F6D-D8A6BB3E66A4"
  # would be stored in "2A.json.gz".
  items/
    2025-01.json.gz   # Timeline items for January 2025
    2025-02.json.gz   # Timeline items for February 2025
    ...
  samples/
    2025-W01.json.gz  # Location samples for week 1, 2025
    2025-W02.json.gz  # Location samples for week 2, 2025
    ...
```

#### File Formats

metadata.json:
```json
{
  "schemaVersion": "1.0.0",
  "exportMode": "bucketed",
  "exportDate": "2025-01-10T13:45:00Z",
  "stats": {
    "placeCount": 5640,
    "itemCount": 38308,
    "sampleCount": 6989051
  }
}
```

places/XX/places.json.gz:
- Gzipped array of Place objects
- Grouped by first two characters of place UUID
- Each place includes full metadata (visit stats, etc)

items/YYYY-MM.json.gz:
- Gzipped array of TimelineItem objects
- One file per month
- Items include all metadata but no samples
- Edge relationships (previousItemId/nextItemId) preserved

samples/YYYY-WW.json.gz:
- Gzipped array of LocomotionSample objects
- Grouped by UTC week number
- Full sample data including activity classification

### 2. Single File Format

Designed for data analysis and sharing specific date ranges. All data contained in one gzipped JSON file.

#### File Structure
```
2025-01-05.json or 2025-01-05.json.gz   # Single file containing contents:
{
  "schemaVersion": "1.0.0",
  "exportMode": "singleFile",
  "dateRange": {
    "start": "2025-01-05",
    "end": "2025-01-05"
  },
  "items": [
    {
      "id": "9F264AC1-992C-4E7D-B333-79F0C9FEEE22",
      "type": "visit",  // or "trip"
      "startDate": "2025-01-05T10:00:00Z",
      "endDate": "2025-01-05T11:30:00Z",
      "previousItemId": "1A95C320-D04E-4F53-8F6D-D8A6BB3E66A4",
      "nextItemId": "E721F2D5-AD31-4F8B-90EE-8E92F1123D64",
      ...
    },
    ...
  ],
  "places": [
    {
      "id": "2A95C320-D04E-4F53-8F6D-D8A6BB3E66A4",
      "name": "Place Name",
      "center": {
        "latitude": 35.6762,
        "longitude": 139.6503
      },
      ...
    },
    ...
  ],
  "samples": [
    {
      "id": "43FF6A12-7890-4DEF-B123-456789ABCDEF",
      "date": "2025-01-05T10:00:00Z",
      "latitude": 35.6762,
      "longitude": 139.6503,
      "timelineItemId": "9F264AC1-992C-4E7D-B333-79F0C9FEEE22",
      ...
    },
    ...
  ]
}
```

## Data Types

### TimelineItem
Common fields for both Visits and Trips:
```typescript
{
  id: string              // UUID
  type: "visit" | "trip"  // Item type discriminator
  startDate: string      // ISO8601 datetime with timezone
  endDate: string        // ISO8601 datetime with timezone
  previousItemId: string // UUID of previous item (null if first)
  nextItemId: string     // UUID of next item (null if last)
  deleted: boolean       // Soft delete flag
  isWorthKeeping: boolean
  
  // Type-specific fields based on "type":
  // Visit-specific fields when type="visit":
  placeId: string | null
  confirmedPlace: boolean
  
  // Trip-specific fields when type="trip":
  activityType: string | null  // e.g. "walking", "cycling"
  confirmedType: boolean
}
```

### Place
```typescript
{
  id: string           // UUID
  name: string | null
  center: {
    latitude: number
    longitude: number
  }
  radius: {
    mean: number    // meters
    sd: number      // standard deviation in meters
  }
  visitCount: number
}
```

### LocomotionSample
```typescript
{
  id: string          // UUID
  date: string        // ISO8601 datetime with timezone
  timelineItemId: string
  
  // Location
  latitude: number | null
  longitude: number | null
  horizontalAccuracy: number | null
  
  // Motion
  movingState: "stationary" | "moving"
  activityType: string | null  // e.g. "walking", "cycling"
  stepHz: number | null
  courseVariance: number | null
  
  // State
  recordingState: "recording" | "sleeping"
}
```

## Compression
- Files may be either compressed (.json.gz) or uncompressed (.json)
- Implementations must support reading both formats
- Example paths in this doc show .json.gz but .json is equally valid
- Future compression formats may be added (e.g. .json.zst)
- The .gz extension when present indicates gzip compression

## Notes

- All dates are in ISO8601 format with timezone information
- UUIDs are uppercase string format without curly braces
- Empty/null fields should be omitted from JSON
- All file paths and names are case-sensitive
- Week numbers in sample filenames use ISO week date system