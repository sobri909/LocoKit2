# LocoKit2 Import Process

## Overview

The import process safely restores timeline data while preserving all relationships between items. Two key challenges are handled:

1. Maintaining database constraints during import
2. Preserving edge relationships between items

## Import Phases

### Phase 1: Core Data Import
During this phase, all records are imported with null edge relationships to avoid foreign key constraint issues:

1. Places imported first
   - No dependencies on other records
   - Preserves all place metadata and visit stats
   - Handles duplicate places via upsert

2. Timeline Items imported next
   - Visit/Trip type preserved
   - Place relationships maintained
   - Edge relationships temporarily nulled
   - Edge information stored in JSONL format
   - All other metadata preserved

3. Samples imported last
   - Maintains chronological order
   - Preserves timeline item relationships
   - All derived/computed data included

### Phase 2: Edge Restoration  
The import process uses a two-phase approach for handling edge relationships to maintain database constraints:

1. During item import:
   - Items are imported with null edge relationships
   - Original edge relationships preserved in temporary JSONL file
   - Each record captures itemId, previousId, and nextId
   - Ensures valid database state during import

2. After items imported:
```sql
UPDATE TimelineItemBase 
SET previousItemId = ?, nextItemId = ?
WHERE id = ?
```

- Edge relationships restored from JSONL records
- Processed in batches of 100 records
- Single transaction per batch for safety
- Foreign key constraints enforced
- No dependency on edge healing system
- Temp file removed after successful restore

## Special Cases

### Interrupted Imports
- Cleanup of edge record file on failure
- Clear state management through PersistenceActor
- Safe resumption from last successful batch

### Importing from Active Exports
- Safe to import from directories that may be updated
- Uses metadata timestamps to understand data window
- Handles incremental backup directories correctly

## Implementation Notes

### Data Validation
- Schema version compatibility check
- Required fields validation
- Foreign key integrity verification
- Date range continuity validation

### Error Handling
- Transaction rollback on failures
- Detailed error reporting
- Partial import recovery where possible
- Verification of restored state

### Performance Considerations
- Batched record imports (100 records per batch)
- Memory usage management through batching
- Efficient JSONL format for edge records
- Background import option for large datasets