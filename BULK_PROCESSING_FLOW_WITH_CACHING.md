# Bulk Processing Flow with Response Caching and Deduplication

## Overview
This document details the processing flow when both Response Caching and Deduplication are implemented.

## Processing Flow

### Step 1: User Initiates Bulk Matching
```
User clicks "Match All Items" on Scope3PcmtSummary record
  ↓
LWC calls USEEIOMatchingService.startBulkMatching(summaryId)
  ↓
Apex validates summary has PcmtEmssnFctrId
  ↓
Enqueue BulkMatchingQueueable job
  ↓
Return job ID to LWC
```

### Step 2: Queueable Initiates Batch
```
BulkMatchingQueueable.execute()
  ↓
Query Scope3PcmtSummary to get PcmtEmssnFctrId
  ↓
Enqueue BulkMatchingBatch with summaryId and pcmtEmssnFctrSetId
  ↓
Batch job starts
```

### Step 3: Batch Start Method
```
BulkMatchingBatch.start()
  ↓
Query all Scope3PcmtItem records:
  WHERE ProcurementSummaryId = :summaryId
  AND PcmtEmssnFctrSetId = null  // Only unmatched items
  ↓
Return iterable of items (batches of 200)
```

### Step 4: Batch Execute Method (Per Batch of 200 Items)
```
BulkMatchingBatch.execute(items)
  ↓
Initialize in-memory deduplication Map<String, MatchingResult>
  ↓
For each item in batch (process max 50 per execution):
  
  Step 4a: Generate Category Hash
    hash = SHA256(cat1|cat2|cat3)
  
  Step 4b: Check Deduplication Map (Memory)
    if (categoryHashToResult.containsKey(hash)) {
      // Found in memory - reuse result
      result = categoryHashToResult.get(hash).clone();
      result.scope3PcmtItemId = item.Id;
      totalDeduplicated++;
      goto Step 4e;
    }
  
  Step 4c: Check Response Cache (Database)
    cachedResponse = LLMResponseCache.getCachedResponse(cat1, cat2, cat3, pcmtEmssnFctrSetId);
    if (cachedResponse != null) {
      // Found in cache - use it
      result = buildMatchingResultFromCache(cachedResponse, item);
      categoryHashToResult.put(hash, result); // Store in memory for deduplication
      totalCached++;
      goto Step 4e;
    }
  
  Step 4d: Call LLM (No cache hit)
    // Pre-filter candidates
    candidateCodes = KeywordMatchingService.findCandidateNaicsCodes(...);
    
    // Get candidate descriptions
    candidateDescriptions = queryFactorSetForCandidates(...);
    
    // Call LLM
    llmResponse = LLMService.suggestNaicsCode(cat1, cat2, cat3, candidateCodes, candidateDescriptions);
    
    // Save to cache for future use
    LLMResponseCache.saveResponse(cat1, cat2, cat3, pcmtEmssnFctrSetId, llmResponse);
    
    // Build result
    result = buildMatchingResult(llmResponse, item, pcmtEmssnFctrSetId);
    
    // Store in deduplication map for this batch
    categoryHashToResult.put(hash, result);
  
  Step 4e: Process Result
    if (result.status == 'MATCHED' && result.confidenceScore >= 0.7) {
      // Auto-apply high confidence matches
      item.PcmtEmssnFctrSetItemId = result.recommendedFactorId;
      item.Match_Confidence_Score__c = result.confidenceScore;
      item.Match_Reasoning__c = result.reasoning;
      item.Match_Source__c = 'AI Suggested';
      itemsToUpdate.add(item);
      totalMatched++;
    } else {
      // Low confidence or no match - needs review
      totalNeedsReview++;
    }
  
  totalProcessed++;
  
  // Check governor limits
  if (Limits.getCallouts() >= 90) {
    break; // Stop processing this batch, continue in next execution
  }
  
  ↓
Update Scope3PcmtItem records (batch update)
  ↓
Continue to next batch of 200 items
```

### Step 5: Batch Finish Method
```
BulkMatchingBatch.finish()
  ↓
Update Scope3PcmtSummary with:
  - Bulk_Matching_Status__c = 'Complete'
  - Bulk_Matching_Completed_Date__c = DateTime.now()
  - Bulk_Matching_Items_Processed__c = totalProcessed
  - Bulk_Matching_Items_Matched__c = totalMatched
  - Bulk_Matching_Items_Needing_Review__c = totalNeedsReview
  - Bulk_Matching_Cache_Hits__c = totalCached (new field)
  - Bulk_Matching_Deduplicated__c = totalDeduplicated (new field)
  ↓
Send notification (optional)
```

## Cost Savings Example

### Scenario: Processing 10,000 Items

**Without Caching/Deduplication:**
- 10,000 items = 10,000 LLM calls = $225

**With Caching + Deduplication:**
- 7,000 unique category combinations
- 2,000 duplicates within batch (deduplication)
- 1,000 cached from previous runs (response cache)

**Processing:**
- 6,000 new combinations → LLM calls = $135
- 2,000 deduplicated → $0 (reused from memory)
- 1,000 cached → $0 (retrieved from database)
- 1,000 already matched → $0 (skipped)

**Total Cost: $135 (40% savings)**

## Statistics Tracking

### Custom Fields on Scope3PcmtSummary
- `Bulk_Matching_Cache_Hits__c` (Number) - Items using response cache
- `Bulk_Matching_Deduplicated__c` (Number) - Items using deduplication
- `Bulk_Matching_LLM_Calls__c` (Number) - Actual LLM API calls made
- `Bulk_Matching_Cost_Saved__c` (Currency) - Estimated cost savings

### Calculation
```
LLM_Calls = Total_Processed - Cache_Hits - Deduplicated
Cost_Saved = (Cache_Hits + Deduplicated) × $0.0225
```

## Error Handling

### Cache Errors
- If cache lookup fails → Continue with LLM call
- If cache save fails → Log error, continue processing
- Don't block processing due to cache issues

### Deduplication Errors
- If memory map grows too large → Clear old entries
- If hash collision (extremely rare) → Both items get LLM call
- Don't block processing due to deduplication issues

## Performance Considerations

### Response Cache Queries
- **Optimization**: Batch query cache entries at start of batch execution
- Query all potential hashes upfront, store in Map
- Reduces SOQL queries from N to 1

### Deduplication Memory
- **Limit**: Keep Map size reasonable (clear if > 10,000 entries)
- **Stateful**: Map persists across batch executions (Database.Stateful)
- **Clear**: Clear map when batch completes

## Testing Scenarios

### Test 1: First Run (No Cache)
- Process 100 items
- Verify: 100 LLM calls, 100 cache entries created
- Verify: Deduplication works within batch

### Test 2: Second Run (With Cache)
- Process 100 items (50 new, 50 same as first run)
- Verify: 50 LLM calls, 50 cache hits
- Verify: Cache entries updated with Last_Used_Date

### Test 3: Duplicates in Same Batch
- Process 100 items (20 unique, 80 duplicates)
- Verify: 20 LLM calls, 80 deduplicated
- Verify: All 100 items processed correctly

### Test 4: Mixed Scenario
- Process 100 items:
  - 30 new (LLM calls)
  - 40 cached (from previous run)
  - 30 duplicates (within batch)
- Verify: 30 LLM calls, 40 cache hits, 30 deduplicated
- Verify: Statistics tracked correctly
