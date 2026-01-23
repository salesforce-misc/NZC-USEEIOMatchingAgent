# Bulk Matching Design

## Overview
Extend the USEEIO Matching Service to process **all** `Scope3PcmtItem` records related to a `Scope3PcmtSummary` in a single background operation. The user initiates the process from the `Scope3PcmtSummary` record page, and the system processes matches asynchronously, returning only items that need human review.

## Requirements
- **Volume**: Process thousands to tens of thousands of `Scope3PcmtItem` records per `Scope3PcmtSummary`
- **UI Location**: Lightning Web Component on `Scope3PcmtSummary` object (not `Scope3PcmtItem`)
- **User Experience**: 
  - User clicks "Match All Items" button on the summary record
  - System processes all related items in the background
  - User returns to see only items needing review (no match found or low confidence)
- **Processing**: Asynchronous background processing (non-blocking)
- **Cost Optimization**: Minimize LLM API calls where possible
- **Salesforce Limits**: Handle governor limits for large volumes
- **LLM Integration**: Continue using existing Models API approach (no grounding changes)

## Architecture: Batch Apex with Queueable Chaining

### Recommended Approach: Hybrid Batch + Queueable

**Why Batch Apex?**
- Handles very large volumes (10,000+ records)
- Automatic batching (200 records per batch)
- Built-in retry mechanism
- Can't be called directly from LWC, so we'll use Queueable as entry point

**Why Queueable Entry Point?**
- Can be called from LWC via `@AuraEnabled` method
- Can enqueue Batch Apex job
- Provides immediate feedback to user

**Flow:**
1. User clicks button on `Scope3PcmtSummary` record page
2. LWC calls Apex method `startBulkMatching(scope3PcmtSummaryId)`
3. Apex enqueues `BulkMatchingQueueable` job
4. Queueable queries all related `Scope3PcmtItem` records
5. Queueable enqueues `BulkMatchingBatch` job
6. Batch processes items in chunks of 200
7. Each batch execution:
   - Processes up to 50 items (respecting callout limits)
   - Updates `Scope3PcmtItem` records directly with matches
   - Only updates if confidence >= threshold (e.g., 0.7)
8. User polls for completion or receives notification
9. UI shows only items needing review (no match or low confidence)

## Implementation Details

### Step 1: Entry Point - Queueable Class
```apex
public class BulkMatchingQueueable implements Queueable {
    private Id scope3PcmtSummaryId;
    
    public BulkMatchingQueueable(Id summaryId) {
        this.scope3PcmtSummaryId = summaryId;
    }
    
    public void execute(QueueableContext context) {
        // Query all Scope3PcmtItem records for this summary
        // Enqueue Batch Apex job
        Database.executeBatch(new BulkMatchingBatch(scope3PcmtSummaryId), 200);
    }
}
```

### Step 2: Batch Apex Class
```apex
public class BulkMatchingBatch implements Database.Batchable<Scope3PcmtItem>, Database.Stateful {
    private Id scope3PcmtSummaryId;
    private Id pcmtEmssnFctrSetId; // Cached from summary
    private Integer totalProcessed = 0;
    private Integer totalMatched = 0;
    private Integer totalNeedsReview = 0;
    private Integer totalCached = 0; // Items using cache
    private Integer totalDeduplicated = 0; // Items using deduplication
    
    // In-memory deduplication map (cleared between batches, but Stateful keeps it)
    private Map<String, MatchingResult> categoryHashToResult = new Map<String, MatchingResult>();
    
    public Iterable<Scope3PcmtItem> start(Database.BatchableContext bc) {
        // Query all items for this summary
        return [SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                       ProcurementSummaryId, PcmtEmssnFctrSetItemId
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND PcmtEmssnFctrSetItemId = null]; // Only unmatched items
    }
    
    public void execute(Database.BatchableContext bc, List<Scope3PcmtItem> items) {
        // Process in chunks of 50 (respecting 100 callout limit)
        // For each item:
        //   1. Check Response Cache (database) - if found, use it
        //   2. Check Deduplication Map (memory) - if found, reuse it
        //   3. If not found, call LLM and store in both cache and map
        // Update records directly if confidence >= 0.7
        // Track statistics (cached, deduplicated, LLM calls)
    }
    
    public void finish(Database.BatchableContext bc) {
        // Update summary record with completion status
        // Include cache/deduplication statistics
        // Send notification if needed
    }
}
```

### Step 3: LWC on Scope3PcmtSummary
- Button: "Match All Items"
- Status indicator: "Processing...", "Complete", "Error"
- Results table: Show only items needing review
- Poll for completion every 5-10 seconds

### Step 4: Apex Method for LWC
```apex
@AuraEnabled(cacheable=false)
public static String startBulkMatching(Id scope3PcmtSummaryId) {
    // Validate summary has PcmtEmssnFctrId
    // Enqueue BulkMatchingQueueable
    // Return job ID for tracking
}

@AuraEnabled(cacheable=true)
public static BulkMatchingStatus getMatchingStatus(Id scope3PcmtSummaryId) {
    // Return current status, counts, etc.
}

@AuraEnabled(cacheable=true)
public static List<Scope3PcmtItem> getItemsNeedingReview(Id scope3PcmtSummaryId) {
    // Return items with no match or low confidence
}
```

## Cost Optimization Strategies

### 1. Response Caching (Persistent)
- **Purpose**: Cache LLM responses in custom object `LLM_Response_Cache__c`
- **How it works**: 
  - First time a category combination is seen → Call LLM → Store result in cache
  - Subsequent times (even across different bulk runs) → Retrieve from cache → No LLM call
- **Storage**: Custom object in customer's Salesforce org (persists indefinitely)
- **Impact**: 20-30% cost reduction if category combinations repeat across time
- **Implementation**: `LLMResponseCache` service class handles cache lookups and storage

### 2. Deduplication (In-Memory)
- **Purpose**: Identify duplicate items within the same bulk processing batch
- **How it works**:
  - First occurrence of category combination → Call LLM → Store in memory Map
  - Duplicate items in same batch → Reuse result from Map → No LLM call
- **Storage**: In-memory Map (cleared when batch completes)
- **Impact**: 30-40% cost reduction if items repeat within same batch
- **Implementation**: Built into `BulkMatchingBatch.execute()` method

### 3. Skip Already Matched Items
- Only process items where `PcmtEmssnFctrSetItemId = null`
- Query filter: `WHERE ProcurementSummaryId = :summaryId AND PcmtEmssnFctrSetItemId = null`

### 4. Confidence Threshold for Auto-Apply
- Only auto-apply matches with confidence >= 0.7 (configurable)
- Items with lower confidence require manual review
- Reduces unnecessary LLM calls for edge cases

### 5. Batch Processing Limits
- Process max 50 items per batch execution (respecting 100 callout limit)
- Each item = 1 LLM callout
- Leaves buffer for retries/errors

### 6. Skip Items Without Categories
- Pre-filter items with no spending categories
- Mark as "NO_MATCH" without LLM call
- Saves API costs

### 7. Candidate Code Pre-filtering
- Use existing `KeywordMatchingService` to narrow candidates
- Only call LLM if candidates found
- Reduces prompt complexity and improves accuracy

### Combined Cost Impact
- **Baseline**: $2,250 for 100,000 items
- **With Caching + Deduplication**: ~$1,350-1,575 (40-50% reduction)
- **Additional savings from other strategies**: Further 20-30% reduction possible

## Governor Limits Management

### Callout Limits
- **Limit**: 100 callouts per transaction
- **Strategy**: Process max 50 items per batch execution
- **Safety Buffer**: Stop at 90 callouts to leave room for errors

### SOQL Limits
- **Limit**: 100 queries per transaction
- **Strategy**: 
  - Batch queries in `start()` method
  - Use Maps for lookups (summary, factor set items)
  - Minimize queries in `execute()` method

### DML Limits
- **Limit**: 150 DML statements per transaction
- **Strategy**: Batch updates using `Database.update(items, false)`
- **Process**: Update up to 50 items per batch execution

### CPU Time
- **Limit**: 10 seconds CPU time per transaction
- **Strategy**: Monitor CPU usage, process smaller chunks if needed
- **Fallback**: If CPU limit approached, stop and chain to next batch

### Heap Size
- **Limit**: 6 MB heap size
- **Strategy**: Process in small batches, avoid large collections

## Data Model Updates

### Direct Record Updates
- **Approach**: Update `Scope3PcmtItem` records directly
- **Fields Updated**:
  - `PcmtEmssnFctrSetItemId` (if confidence >= 0.7)
  - `Match_Confidence_Score__c`
  - `Match_Reasoning__c`
  - `Match_Source__c` = 'AI Suggested'
- **Items Not Updated**: 
  - Low confidence matches (< 0.7)
  - No match found
  - These appear in review list

### Status Tracking
- **Custom Field on Scope3PcmtSummary**: `Bulk_Matching_Status__c` (Picklist)
  - Values: 'Not Started', 'In Progress', 'Complete', 'Error'
- **Custom Field**: `Bulk_Matching_Job_Id__c` (Text) - Store Batch Job ID
- **Custom Field**: `Bulk_Matching_Completed_Date__c` (DateTime)
- **Custom Field**: `Bulk_Matching_Items_Processed__c` (Number)
- **Custom Field**: `Bulk_Matching_Items_Matched__c` (Number)
- **Custom Field**: `Bulk_Matching_Items_Needing_Review__c` (Number)

## UI Component Design

### Location
- **Object**: `Scope3PcmtSummary`
- **Placement**: Record page (Lightning App Builder)
- **Component Name**: `bulkMatchingSummary`

### Features
1. **Initiate Matching**
   - Button: "Match All Items"
   - Disabled if: Already in progress, no items to match, missing factor set

2. **Status Display**
   - Current status: "Not Started", "Processing...", "Complete", "Error"
   - Progress: "X of Y items processed"
   - Statistics: "Z items matched, W need review"

3. **Results Table** (Only items needing review)
   - Columns:
     - Item Name/ID
     - Spending Categories
     - Suggested NAICS Code (if any)
     - Confidence Score
     - Reasoning
     - Actions (Apply Match, Reject, Manual Select)

4. **Polling**
   - Poll every 5-10 seconds when status = "In Progress"
   - Stop polling when status = "Complete" or "Error"

## Error Handling

### Individual Item Failures
- Continue processing other items
- Log error to `Match_Reasoning__c` field
- Mark item as needing review

### Batch Failures
- Batch Apex has built-in retry (up to 3 times)
- Update status to "Error" if all retries fail
- Log error details to summary record

### LLM API Failures
- Retry once for transient errors
- Mark item as needing review if retry fails
- Continue with next items

## Testing Strategy

### Unit Tests
- Test with small batches (10-50 items)
- Test error scenarios
- Test governor limit handling

### Integration Tests
- Test with medium batches (100-500 items)
- Test with large batches (1000+ items)
- Monitor governor limits
- Verify cost optimization

### User Acceptance Tests
- Test UI workflow
- Test status updates
- Test results filtering
- Test error recovery

## Cost Estimation

### LLM API Costs
- **Assumption**: ~$0.01 per LLM call (varies by model)
- **10,000 items**: ~$100
- **100,000 items**: ~$1,000

### Optimization Impact
- **Skip already matched**: Saves 0% (only unmatched processed)
- **Skip no categories**: Saves ~5-10% (if 5-10% have no categories)
- **Confidence threshold**: Saves 0% (still need to call LLM to get confidence)
- **Total potential savings**: ~5-10%

## Next Steps

1. **Create Custom Fields** on `Scope3PcmtSummary` for status tracking
2. **Create Queueable Class** (`BulkMatchingQueueable`)
3. **Create Batch Apex Class** (`BulkMatchingBatch`)
4. **Create LWC** (`bulkMatchingSummary`) for `Scope3PcmtSummary`
5. **Create Apex Methods** for LWC integration
6. **Add Unit Tests** for all classes
7. **Test with small batch** (10-50 items)
8. **Test with medium batch** (100-500 items)
9. **Monitor costs** and optimize further
10. **Deploy to production**

## Alternative: Simplified Approach (If Batch Apex Too Complex)

If Batch Apex proves too complex, consider:
- **Queueable with Chaining**: Process 50 items per queueable, chain to next
- **Limitation**: Max 50 chain depth = 2,500 items per summary
- **Workaround**: For >2,500 items, split into multiple queueable jobs
