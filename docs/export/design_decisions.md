# Design Decisions

Technical rationale and notes for key design decisions in the export/import system.

## Export Format Decisions

### Two Format Approach
Decided on two distinct formats rather than a one-size-fits-all solution:

1. Bucketed/Compressed Format
- Efficiently handles large scale (millions of records)
- Supports incremental backups
- Grouping by time period and UUID prefix for manageability
- Compression for storage efficiency

2. Single File Format
- Simple format for analysis/scripting
- Self-contained exports for sharing
- Still compressed but unified structure
- Easy to process with standard tools

This provides clear formats for different use cases while keeping the implementation manageable.

### Compression Strategy
- Using gzip for wide tool compatibility
- Applied at individual file level for selective decompression
- Weekly batching for samples proven in production
- Monthly batching for items balances size vs granularity
- UUID prefix bucketing for places avoids temporal clustering

### Two-Phase Import Strategy
Core challenge was preserving bidirectional edge relationships while maintaining database constraints.

Previous approach using edge healing had issues:
- Led to potential data loss
- Couldn't guarantee exact edge preservation
- Complex rebuild logic

New approach:
1. Import with null edges to satisfy constraints
2. Restore edges in single transaction
3. Benefits:
   - Exact relationship preservation
   - Maintains database constraints
   - Simple, reliable implementation
   - No edge healing dependency

### App Layer State Management
Considered but rejected adding import state to database schema due to:
- Unnecessary schema complexity
- Storage overhead in production
- Schema change costs

Instead using PersistenceActor to:
- Manage import/export state
- Block recording/processing
- Coordinate app-wide state

Benefits:
- No schema changes
- Clean separation of concerns
- Simpler rollback handling

## Performance Considerations

### Data Scale
Tested with real-world volumes:
- ~5.6K places (~2.1MB)
- ~38K timeline items (~24MB)
- ~7M samples (~4.5GB)

### File Organization
- Weekly sample files manage read/write load
- Monthly item files balance size vs backup granularity
- Place bucketing prevents single directory overload
- Compression reduces storage and transfer costs

### Future Optimizations
- Batch processing for large datasets
- Memory usage optimization
- Additional compression options if needed
- Progress vs performance tradeoffs

## Implementation Notes

### Sample File Organization
Careful consideration given to sample file organization:
- UTC week-based files chosen over alternatives
- YYYY-WW.json format provides timezone safety
- UTC basis prevents daylight saving issues
- Week files provide natural date-range divisions
- Handles orphaned samples cleanly
- Minimizes filesystem/iCloud IO
- Efficient for date-range operations

Key challenges handled:
- Timeline items may span week boundaries
- Need efficient sample lookup during import
- Week files may need partial updates
- Timezone complexity with international data

### Future Data Merging
Planned lastSaved timestamp system:
- Add lastSaved column to core tables
- SQL triggers to auto-update on writes
- Use timestamps to resolve import conflicts
- Only update if import data is newer
- Enables proper merging between devices

### Known Edge Cases
- Edge management in two-phase import
- Transaction size limits with sample data
- Progress granularity vs performance
- Crash recovery during import
- Handling app termination mid-export
- Memory pressure with large datasets
- iCloud upload interruptions

### Migration Strategy
1. Initial implementation with core functionality
2. Add format versioning using semver
3. Add compression and batching
4. Implement backup scheduling
5. Add data merging system
6. Consider cloud sync features

Core principle: Maintain backward compatibility while enabling future enhancements. Each version should be able to read data from previous versions.

### Edge Case Handling
- Import interruption recovery
- Partial export cleanup
- Download failures
- Storage space exhaustion
- Large transaction management
- Memory pressure handling
- Background task time limits