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

## Implementation Notes

### File Organization Implementation
1. Place Bucketing:
   ```swift
   // Group by first 2 chars of UUID
   var bucketedPlaces: [String: [Place]] = [:]
   for place in places {
       let prefix = String(place.id.prefix(2)).uppercased()
       bucketedPlaces[prefix, default: []].append(place)
   }
   ```

2. Month-Based Items:
   ```swift
   // Group by YYYY-MM
   var monthlyItems: [String: [TimelineItem]] = [:]
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM"
   
   for item in items {
       guard let startDate = item.dateRange?.start else { continue }
       let monthKey = formatter.string(from: startDate)
       monthlyItems[monthKey, default: []].append(item)
   }
   ```
   
   **Note on Soft-Deleted Items (2025-07-01):**
   - Items without startDate are excluded from export
   - This primarily affects soft-deleted items (nil dates after sample removal)
   - Export counts only include items with valid startDate
   - This is pragmatic: deleted items have no samples or purpose in restore

3. Week-Based Samples:
   ```swift
   // Group by UTC week
   var calendar = Calendar.current
   calendar.timeZone = TimeZone(identifier: "UTC")!
   let weekId = String(format: "%4d-W%02d", year, weekOfYear)
   ```

Key implementation considerations:
- Sort before grouping for consistent organization
- Use Calendar for proper week calculations
- Maintain proper timezone handling
- Clean error handling throughout
- Pre-create all directories at export start

### Future Compression Integration
Planned approach:
1. File handling first:
   - Check extensions to detect format (.json vs .json.gz)
   - Support both reading and writing both formats
   - Graceful fallback to uncompressed

2. Memory considerations:
   - Stream compression where possible
   - Avoid loading full files into memory
   - Maintain batching with either format

3. Testing strategy:
   - Compare file sizes between formats
   - Measure memory impact during export/import
   - Test format auto-detection
   - Verify streaming performance

## Data Integrity

### Core Data Organization
Decision to keep objects separate with foreign key relationships:
- Avoids data duplication in both formats
- Maintains clean, consistent data relationships
- More efficient for partial/incremental updates
- Consistent between single-file and multi-file formats
- Better for memory management with large datasets

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
- YYYY-Www.json format provides timezone safety
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