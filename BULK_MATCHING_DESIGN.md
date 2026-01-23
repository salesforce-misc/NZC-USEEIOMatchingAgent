# Bulk Matching Design

## Overview
Extend the USEEIO Matching Service to process multiple `Scope3PcmtItem` records in a single operation, rather than one at a time.

## Requirements
- Process hundreds to hundreds of thousands of records
- Handle governor limits (SOQL, DML, callouts, CPU time)
- Provide progress feedback
- Handle errors gracefully (don't fail entire batch if one item fails)
- Return results for all processed items

## Architecture Options

### Option 1: Synchronous Batch Processing (Recommended for POC)
**Use Case:** Small to medium batches (up to ~1000 records)

**Approach:**
- Create `matchSpendItemsToFactors(List<Id> scope3PcmtItemIds)` method
- Process in chunks (e.g., 10-50 at a time) to respect governor limits
- Return `List<MatchingResult>` with status for each item
- Can be called from LWC with progress updates

**Pros:**
- Simpler implementation
- Immediate results
- Easier error handling
- Can show progress in UI

**Cons:**
- Limited by synchronous governor limits
- May timeout for very large batches
- Blocks user interaction during processing

### Option 2: Queueable Apex (Recommended for Medium Batches)
**Use Case:** Medium batches (1000-10,000 records)

**Approach:**
- Create `BulkMatchingQueueable` class
- Process in chunks, chain to next queueable if more records remain
- Store results in custom object or update records directly
- Provide status via custom object or platform events

**Pros:**
- Handles larger volumes
- Non-blocking
- Can chain multiple queueables
- Better for async processing

**Cons:**
- More complex
- Results not immediately available
- Need status tracking mechanism

### Option 3: Batch Apex (Recommended for Large Batches)
**Use Case:** Large batches (10,000+ records)

**Approach:**
- Create `BulkMatchingBatch` class implementing `Database.Batchable`
- Process in batches of 200 records
- Update records directly in `execute` method
- Use `Database.Stateful` to track overall progress

**Pros:**
- Handles very large volumes
- Automatic batching
- Built-in retry mechanism
- Best for scheduled/automated runs

**Cons:**
- Most complex
- Results not immediately available
- Requires monitoring
- Can't be called directly from LWC

## Recommended Approach: Hybrid

### Phase 1: Synchronous Batch (POC)
Start with Option 1 for immediate results and easier testing:
- Process 10-20 items at a time
- Return results immediately
- Show progress in UI

### Phase 2: Queueable (Production)
If volumes exceed synchronous limits:
- Implement Option 2
- Process in chunks of 50-100
- Chain queueables for larger batches
- Store results and provide status

## Implementation Plan

### Step 1: Create Bulk Matching Method
```apex
@AuraEnabled(cacheable=false)
public static BulkMatchingResult matchSpendItemsToFactors(List<Id> scope3PcmtItemIds) {
    // Process in chunks
    // Return results for all items
}
```

### Step 2: Handle Governor Limits
- **SOQL**: Batch queries to avoid 100 query limit
- **Callouts**: Batch LLM calls (if possible) or process sequentially
- **DML**: Batch updates
- **CPU Time**: Monitor and chunk processing

### Step 3: Error Handling
- Continue processing even if one item fails
- Collect errors and return with results
- Log failures for debugging

### Step 4: Progress Tracking
- Return processed count vs total
- Update UI periodically (if synchronous)
- Store status in records (if async)

## Key Considerations

### LLM Call Limits
- Each match requires 1 LLM callout
- 100 callout limit per transaction
- **Solution**: Process max 50-100 items per transaction, chain if needed

### SOQL Limits
- Need to query Scope3PcmtItem, Scope3PcmtSummary, PcmtEmssnFctrSetItem
- **Solution**: Batch queries, use Map<Id, Record> for lookups

### DML Limits
- 150 DML statements per transaction
- **Solution**: Batch updates using `Database.update(list, false)`

### CPU Time
- 10 seconds CPU time limit
- **Solution**: Process in smaller chunks, monitor CPU usage

## Data Model Considerations

### Option A: Update Records Directly
- Update `Scope3PcmtItem` records as matches are found
- Simple, but no audit trail

### Option B: Create Matching Results Object
- Store results in custom object
- Allows review before applying
- Better audit trail

## UI Considerations

### Synchronous Approach
- Show progress bar
- Update results table as items complete
- Allow cancellation (if possible)

### Async Approach
- Show "Processing..." status
- Poll for completion
- Show results when done
- Email notification option

## Next Steps
1. Implement synchronous bulk matching method
2. Add progress tracking
3. Test with small batches (10-50 items)
4. Optimize for larger batches
5. Consider async approach if needed
