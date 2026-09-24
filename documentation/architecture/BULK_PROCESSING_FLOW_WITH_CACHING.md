# Bulk Processing Flow with Response Caching and Deduplication

## Overview

This document details the step-by-step execution flow when bulk matching runs, covering how the deduplication map, response cache, and Agentforce LLM calls interact within and across batch executions. For the design rationale and governor limit strategy, see [BULK_MATCHING_DESIGN.md](BULK_MATCHING_DESIGN.md).

---

## Step 1: User Initiates Bulk Matching

```
User clicks "Run Bulk Matching" on Scope3PcmtSummary record
  ↓
bulkMatchingSummary LWC calls USEEIOMatchingService.startBulkMatching(summaryId)
  ↓
Apex validates summary has PcmtEmssnFctrId configured
  ↓
Enqueue BulkMatchingQueueable
  ↓
Return job ID to LWC
```

---

## Step 2: Queueable Initializes the Job

```
BulkMatchingQueueable.execute()
  ↓
Query Scope3PcmtSummary — validate PcmtEmssnFctrId is set
  ↓
Set Bulk_Matching_Status__c = 'In Progress'
Set Bulk_Matching_Job_Id__c = context.getJobId()
  ↓
Construct BulkMatchingBatch(summaryId):
  — Query and cache Scope3PcmtSummary
  — Load LLM_Config__mdt (Default): confidenceThreshold, llmScoreMedium
  — Initialize statistics counters and deduplication map
  ↓
Database.executeBatch(batch, 25)
```

---

## Step 3: Batch Start Method

```
BulkMatchingBatch.start()
  ↓
Query all unmatched Scope3PcmtItem records:
  WHERE ProcurementSummaryId = :summaryId
  AND PcmtEmssnFctrSetItemId = null
  ORDER BY Id
  ↓
Return iterable — Salesforce delivers these to execute() in chunks of 25
```

---

## Step 4: Batch Execute Method (Per Chunk of 25 Items)

Each `execute()` call runs three sequential phases. DML is not allowed during Phase 1 (callouts active).

```
BulkMatchingBatch.execute(items)
  ↓
Check governor limits — exit early if callouts ≥ 90 or CPU ≥ 55,000ms
```

### Phase 1 — Callouts (No DML)

For each item (up to 25, or until a governor limit is approached):

```
  Generate category hash = SHA256(cat1 + "|" + cat2 + "|" + cat3)
  
  Check 1: In-Memory Deduplication Map
    if (categoryHashToResult.containsKey(hash)):
      result = clone of cached result with this item's ID
      totalDeduplicated++
      → skip to Phase 3 processing
  
  Check 2: Response Cache (LLM_Response_Cache__c)
    Query: WHERE Category_Hash__c = :hash AND Factor_Set_ID__c = :pcmtEmssnFctrSetId
    if (cache hit):
      Build LLMResponse from cache record
      result = buildMatchingResultFromCache(cachedResponse, item, pcmtEmssnFctrSetId)
      categoryHashToResult.put(hash, result)   ← store for deduplication
      totalCached++
      → skip to Phase 3 processing
  
  Check 3: Agentforce LLM Call
    candidates = KeywordMatchingService.getTopCandidates(cat1, cat2, cat3, 50)
    llmResponse = LLMService.suggestNaicsCode(cat1, cat2, cat3, candidates)
    totalLLMCalls++
    
    result = buildMatchingResult(llmResponse, item, pcmtEmssnFctrSetId)
    categoryHashToResult.put(hash, result)   ← store for deduplication
    
    if (result.status == 'MATCHED' or 'REQUIRES_REVIEW'):
      Collect CacheEntry for deferred save in Phase 2
  
  itemResults.put(item.Id, result)
  totalProcessed++
```

### Phase 2 — Cache Saves (Post-Callout DML)

All callouts are complete. DML is now safe.

```
For each CacheEntry collected in Phase 1:
  LLMResponseCache.saveResponse(cat1, cat2, cat3, factorSetId, llmResponse)
  (failures are logged and do not block processing)
```

### Phase 3 — Item Updates (Final DML)

```
For each item in this execution:
  result = itemResults.get(item.Id)
  
  if (result.status == 'MATCHED' AND result.confidenceScore >= confidenceThreshold):
    item.PcmtEmssnFctrSetItemId = result.recommendedFactorId
    item.Match_Confidence_Score__c = result.confidenceScore
    item.Match_Reasoning__c = result.reasoning
    item.Match_Source__c = 'AI Suggested'
    item.Review_Status__c = 'Passed Confidence Match'
    totalMatched++
  
  else:
    item.Review_Status__c = 'Pending Review'
    item.Match_Confidence_Score__c = result.confidenceScore  (if available)
    item.Match_Reasoning__c = result.reasoning               (if available)
    totalNeedsReview++

Database.update(itemsToUpdate, false)
  (partial success — individual failures are logged, others continue)
```

### Incremental Progress Update

```
After DML completes, update Scope3PcmtSummary with running totals:
  Bulk_Matching_Items_Processed__c = totalProcessed
  Bulk_Matching_Items_Matched__c   = totalMatched
  Bulk_Matching_Items_Needing_Review__c = totalNeedsReview
  Bulk_Matching_Cache_Hits__c      = totalCached
  Bulk_Matching_Deduplicated__c    = totalDeduplicated
  Bulk_Matching_LLM_Calls__c       = totalLLMCalls
  
(This allows the bulkMatchingSummary LWC to show live progress while the job runs)
```

---

## Step 5: Batch Finish Method

```
BulkMatchingBatch.finish()
  ↓
Update Scope3PcmtSummary with final values:
  Bulk_Matching_Status__c          = 'Complete'
  Bulk_Matching_Completed_Date__c  = DateTime.now()
  Bulk_Matching_Items_Processed__c = totalProcessed
  Bulk_Matching_Items_Matched__c   = totalMatched
  Bulk_Matching_Items_Needing_Review__c = totalNeedsReview
  Bulk_Matching_Cache_Hits__c      = totalCached
  Bulk_Matching_Deduplicated__c    = totalDeduplicated
  Bulk_Matching_LLM_Calls__c       = totalLLMCalls
  ↓
(If an exception occurs, a second attempt sets Bulk_Matching_Status__c = 'Error')
```

---

## Deduplication and Cache Interaction

The deduplication map (`categoryHashToResult`) and the response cache (`LLM_Response_Cache__c`) serve the same purpose — avoiding redundant LLM calls — at different scopes:

| Mechanism | Scope | Storage |
|---|---|---|
| In-memory deduplication | Current batch job only | Instance variable on `Database.Stateful` batch |
| Response cache | Across all bulk runs, indefinitely | `LLM_Response_Cache__c` custom object |

The deduplication map is seeded from cache hits. When item A is served from the response cache, its result is also placed in the deduplication map. If item B in a later execution has the same hash, it hits the deduplication map without needing another database query.

---

## Statistics Tracking

The batch tracks six counters as instance variables. Because the batch is `Database.Stateful`, these accumulate across all `execute()` calls:

| Counter | Incremented when |
|---|---|
| `totalProcessed` | Every item is processed (regardless of outcome) |
| `totalMatched` | Item is auto-applied (score ≥ threshold) |
| `totalNeedsReview` | Item goes to Pending Review |
| `totalCached` | Result served from `LLM_Response_Cache__c` |
| `totalDeduplicated` | Result served from in-memory map |
| `totalLLMCalls` | A live Agentforce LLM call is made |

The relationship: `totalProcessed = totalMatched + totalNeedsReview` and `totalLLMCalls = totalProcessed - totalCached - totalDeduplicated` (approximately — items that error before producing a result may not increment matched or needs-review).

---

## Testing Scenarios

### First Run (Empty Cache)

- All items go through the LLM call path
- Verify: `totalLLMCalls` ≈ number of unique category combinations
- Verify: Cache entries created in `LLM_Response_Cache__c`
- Verify: Deduplication map reduces LLM calls for repeated category combinations

### Second Run (Warm Cache)

- Items with same spending categories as first run hit the response cache
- Verify: `totalCached` reflects previously seen combinations
- Verify: `Bulk_Matching_LLM_Calls__c` is lower than first run

### High Duplication Run

- Many items share the same spending categories
- Verify: `totalDeduplicated` is high, `totalLLMCalls` is low
- Verify: All items still receive a result (cloned from deduplication map)

### Mixed Scenario

- Some new combinations (LLM call), some cached, some duplicated within run
- Verify: `totalProcessed = totalCached + totalDeduplicated + totalLLMCalls`
- Verify: Progress fields update after each batch execution (not just at finish)
