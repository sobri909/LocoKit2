# LocoKit2 Export/Import System

A data persistence system for exporting and importing LocoKit2 timeline data. The system supports both full database backups and single-file data exports for analysis and sharing.

## Overview

The export/import system provides:
- Full database backup and restore capability
- Single-file exports for analysis and sharing
- Efficient handling of large datasets (millions of records)
- Compression for storage efficiency
- Clear format specification for third-party integrations

## Documentation

- [Export Format Specification](FORMAT.md) - Detailed format specifications for both export modes
- [Import Process](IMPORT.md) - Details of the import process and edge preservation

## Format Overview

Two supported export formats:

### 1. Bucketed/Compressed Format
Designed for full backups and large datasets:
```
/places/
  00/places.json.gz  # Bucketed by UUID prefix
  01/places.json.gz
  ...
/items/
  2025-01.json.gz    # Monthly files
  2025-02.json.gz
  ...
/samples/
  2025-01.json.gz    # Weekly files
  2025-02.json.gz
  ...
```

### 2. Single File Format
Designed for analysis and sharing:
```
2025-01-05.json.gz   # Single file containing all data for date range
```

See the [format specification](FORMAT.md) for complete details.