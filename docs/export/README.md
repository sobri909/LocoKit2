# LocoKit2 Export/Import System

The LocoKit2 data persistence system supports both full database backups and date range exports. The system provides efficient handling of large datasets with compression and incremental updates.

## Core Features

- Two export formats:
  * Bucketed format for backups and incremental updates
  * Single-file format for sharing and analysis
- Full database or date range exports
- Efficient incremental backup support
- Compression for storage efficiency
- Clear format specification for integrations

## Documentation

- [Format Specification](FORMAT.md) - Detailed format specs and metadata structure
- [Import Process](IMPORT.md) - Details of the import process 

## Format Overview

### Bucketed Format
Designed for backups and incremental updates:
```
/places/              # UUID-bucketed place files
  0.json[.gz]
  1.json[.gz]
  ...
/items/              # Monthly timeline item files  
  2025-01.json[.gz]
  2025-02.json[.gz]
  ...
/samples/            # Weekly sample files
  2025-W01.json[.gz]
  2025-W02.json[.gz]
  ...
```

### Single File Format  
Designed for sharing specific date ranges:
```
2025-01-05.json[.gz]  # Contains all data for date range
```

See the [format specification](FORMAT.md) for complete details.