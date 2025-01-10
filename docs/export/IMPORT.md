# LocoKit2 Import Process

## Overview

The import process is designed to safely restore timeline data while preserving all relationships between items, particularly the bidirectional edge links that maintain timeline continuity.

## Import Phases

### Phase 1: Core Data Import
During this phase, all records are imported with null edge relationships to avoid foreign key constraint issues:

1. Places are imported first
   - No dependencies on other records
   - Preserves all place metadata and visit stats
   - Handles duplicate places if present

2. Timeline Items imported next
   - Visit/Trip type preserved
   - Place relationships maintained
   - Edge relationships (previousItemId/nextItemId) temporarily nulled
   - All other metadata preserved

3. Samples imported last
   - Maintains chronological order
   - Preserves timeline item relationships
   - All derived/computed data included

### Phase 2: Edge Restoration

Once all data is imported, a single transaction restores all edge relationships:
```sql
UPDATE TimelineItemBase
SET previousItemId = ?, nextItemId = ?
WHERE id = ?
```

Key points:
- Single transaction for all edge updates
- Maintains database constraints
- Preserves exact edge relationships
- No dependency on edge healing system

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
- Batched record imports
- Memory usage management
- Progress tracking granularity
- Background import option for large datasets