## Export Format Decisions

### File Organization Strategy
Core approach with clean separation and efficient organization:

1. Places
   - Simple UUID bucketing (00.json through FF.json)
   - No subdirectories for simpler file handling
   - First two chars of UUID determine bucket
   - Uppercase UUIDs for better readability and consistency with Apple
   - No compression initially for easier debugging

2. Items
   - Month-based files (YYYY-MM.json)
   - Pre-sorted by startDate
   - Grouped chronologically for easy access
   - Arrays of items rather than individual files

3. Samples
   - Week-based files using ISO format (YYYY-Www.json)
   - UTC-based for timezone consistency
   - Clear distinction from month files
   - Maintains chronological organization

### Compression Strategy
- Optional compression for flexibility
- Files may be .json or .json.gz
- Implementations must support both
- Starting with uncompressed for simplicity
- Infrastructure ready for future formats

### Data Structure Design
Core decision to keep objects separate with foreign key relationships:
- Avoids data duplication in both formats
- Maintains clean, consistent data relationships
- More efficient for partial/incremental updates
- Consistent between single-file and multi-file formats
- Better for memory management with large datasets

### Compression Strategy
- Using gzip for wide tool compatibility
- Applied to all JSON files, not just samples (improvement over old system)
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

### iOS Constraints
- Full database exports not practical due to:
  * iOS background task time limits
  * Energy impact considerations
  * Storage space constraints
- Multi-day imports need careful handling
- Need to work within iOS background task system

### File Organization
- Weekly sample files manage read/write load
- Monthly item files balance size vs backup granularity
- Place bucketing prevents single directory overload
- All files compressed to minimize storage impact
- Structure considers iCloud Drive limitations with many small files

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

### Legacy Format Support
To be implemented:
- Need conversion tools for existing Arc Timeline exports
- Must maintain ability to read old formats
- Consider both app and library layer conversion needs
- Plan for handling format transitions

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
6. Implement legacy format conversion
7. Consider cloud sync features

Core principle: Maintain backward compatibility while enabling future enhancements. Each version should be able to read data from previous versions.

### Edge Case Handling
- Import interruption recovery
- Partial export cleanup
- Download failures
- Storage space exhaustion
- Large transaction management
- Memory pressure handling
- Background task time limits

### Future Considerations
- More sophisticated recording management during imports
- Write-ahead log style backup/sync system
- Alternative edge management strategies
- Enhanced incremental backup approaches
