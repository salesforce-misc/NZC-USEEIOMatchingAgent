# Bulk Matching Design

## Overview

The bulk matching flow processes all unmatched `Scope3PcmtItem` records for a given `Scope3PcmtSummary` in a single background operation. The user initiates the process from the summary record page; the system handles everything asynchronously and returns only the items that need human review.

## Requirements

- **Volume**: Process thousands to tens of thousands of `Scope3PcmtItem` records per `Scope3PcmtSummary`
- **UI Location**: `bulkMatchingSummary` LWC on the `Scope3PcmtSummary` record page
- **User Experience**:
  - User clicks "Run Bulk Matching" on the summary record
  - System processes all related items in the background
  - Progress fields on the summary update in real time for UI polling
  - On completion, only items needing review are surfaced
- **Processing**: Fully asynchronous — non-blocking for the user
- **Callout efficiency**: Minimize Agentforce LLM calls via caching and in-memory deduplication
- **Salesforce Limits**: Handle governor limits safely across large volumes

---

## Architecture: Queueable + Stateful Batch

### Why Batch Apex?

- Handles very large volumes (10,000+ records) across multiple executions
- `Database.Stateful` allows the in-memory deduplication map and statistics counters to persist across all `execute()` calls for the lifetime of a single job
- Provides built-in chunking — each `execute()` call receives a subset of the full record set

### Why Queueable as Entry Point?

- Can be called from LWC via `@AuraEnabled`
- Validates prerequisites before the batch starts (factor set configured, no job already running)
- Initializes `Scope3PcmtSummary` status fields before handing off to the batch

### Flow

1. User clicks "Run Bulk Matching" on a `Scope3PcmtSummary` record
2. LWC calls `USEEIOMatchingService.startBulkMatching(summaryId)`
3. Apex enqueues `BulkMatchingQueueable`
4. Queueable validates the summary has `PcmtEmssnFctrId`, sets status to `In Progress`, and enqueues `BulkMatchingBatch`
5. Batch `start()` queries all unmatched `Scope3PcmtItem` records for the summary
6. Batch processes items in executions of up to 25 items each:
   - **Phase 1 (callouts)**: For each item — check in-memory deduplication map, then check response cache, then call Agentforce LLM if no hit found. No DML during this phase.
   - **Phase 2 (cache DML)**: Write any new cache entries to `LLM_Response_Cache__c` after all callouts complete.
   - **Phase 3 (item DML)**: Apply matches and update all `Scope3PcmtItem` records. Items scoring ≥ `Auto_Apply_Threshold__c` (default `0.7`) are auto-applied with `Review_Status__c = 'Passed Confidence Match'`. Items below threshold are written with `Review_Status__c = 'Pending Review'`.
   - **Incremental progress update**: Summary status fields are updated after each execution for real-time polling.
7. Batch `finish()` sets `Bulk_Matching_Status__c = 'Complete'` and writes final statistics

---

## Implementation

### Queueable Entry Point

`BulkMatchingQueueable` handles prerequisite validation and initialization before any processing begins:

```apex
public class BulkMatchingQueueable implements Queueable {
    private Id scope3PcmtSummaryId;

    public BulkMatchingQueueable(Id summaryId) {
        this.scope3PcmtSummaryId = summaryId;
    }

    public void execute(QueueableContext context) {
        // Validate summary has PcmtEmssnFctrId — abort if not
        // Set Bulk_Matching_Status__c = 'In Progress'
        // Set Bulk_Matching_Job_Id__c
        Database.executeBatch(new BulkMatchingBatch(scope3PcmtSummaryId), 25);
    }
}
```

### Stateful Batch

`BulkMatchingBatch` implements `Database.Stateful` so the in-memory deduplication map and all statistics counters persist across every `execute()` call. Configuration thresholds are loaded once in the constructor from `LLM_Config__mdt` and stored as instance variables — paid once per batch job regardless of how many executions run.

```apex
public class BulkMatchingBatch implements Database.Batchable<Scope3PcmtItem>, Database.Stateful {
    private Id scope3PcmtSummaryId;
    private Id pcmtEmssnFctrSetId;
    private Scope3PcmtSummary summary;

    // Statistics — persist across execute() calls via Stateful
    private Integer totalProcessed = 0;
    private Integer totalMatched = 0;
    private Integer totalNeedsReview = 0;
    private Integer totalCached = 0;
    private Integer totalDeduplicated = 0;
    private Integer totalLLMCalls = 0;

    // In-memory deduplication — persists across execute() calls via Stateful
    private Map<String, MatchingResult> categoryHashToResult = new Map<String, MatchingResult>();

    // Config loaded once in constructor — not re-queried on every execute()
    private Decimal confidenceThreshold;
    private Decimal llmScoreMedium;

    public BulkMatchingBatch(Id summaryId) {
        // Load LLM_Config__mdt once — instance vars persist via Stateful
        LLM_Config__mdt cfg = LLM_Config__mdt.getInstance('Default');
        this.confidenceThreshold = (cfg?.Auto_Apply_Threshold__c != null) ? cfg.Auto_Apply_Threshold__c : 0.7;
        this.llmScoreMedium      = (cfg?.LLM_Score_Medium__c != null)      ? cfg.LLM_Score_Medium__c      : 0.6;
        // ... query and cache summary record
    }

    public Iterable<Scope3PcmtItem> start(Database.BatchableContext bc) {
        return [SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                       ProcurementSummaryId, PcmtEmssnFctrSetItemId
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND PcmtEmssnFctrSetItemId = null
                ORDER BY Id];
    }

    public void execute(Database.BatchableContext bc, List<Scope3PcmtItem> items) {
        // PHASE 1: All callouts — no DML
        // PHASE 2: Cache saves — post-callout DML
        // PHASE 3: Item updates — final DML
        // Incremental progress update on Scope3PcmtSummary
    }

    public void finish(Database.BatchableContext bc) {
        // Final statistics write + set status = 'Complete'
    }
}
```

### LWC Polling

`bulkMatchingSummary` polls `USEEIOMatchingService.getMatchingStatus()` every 5–10 seconds while `Bulk_Matching_Status__c = 'In Progress'`. Because the batch writes incremental progress after each execution, the UI reflects live counts rather than waiting for the full job to finish.

---

## Callout Efficiency

Every Agentforce LLM call that cannot be served from the response cache or the in-memory deduplication map consumes Agentforce Flex Credits. Two mechanisms reduce the number of live LLM calls:

### Response Caching (Persistent)

- **How it works**: `LLMResponseCache` queries `LLM_Response_Cache__c` before any LLM call. The cache key is a SHA-256 hash of the three spending category values concatenated with a `|` separator, combined with the factor set ID.
- **Persistence**: Cache entries survive indefinitely across bulk runs, orgs restarts, and reruns. A spending category combination that was matched in a previous run never triggers a new LLM call.
- **DML timing**: Cache saves are deferred until after all callouts in a given execution complete (see Deferred DML below).

### In-Memory Deduplication (Within Job)

- **How it works**: The first time a category hash is encountered in the current batch job, the result is stored in `categoryHashToResult` (an instance variable on the `Database.Stateful` batch). Subsequent items with the same hash reuse that result directly from memory — no database query and no LLM call.
- **Scope**: Persists across all `execute()` calls for the lifetime of the job. An item processed in execution 1 can deduplicate an item in execution 50.

### Processing Priority

For each item, the batch checks in this order:

1. In-memory deduplication map (fastest — no I/O)
2. Response cache in `LLM_Response_Cache__c` (database query)
3. Agentforce LLM call (only if no hit above)

---

## Deferred DML Pattern

Salesforce governor limits prohibit DML operations before a callout in the same transaction. The batch separates callout and DML phases within each `execute()` call:

```
PHASE 1 — Callouts only (no DML):
  For each item: dedupe check → cache check → LLM call (if needed)
  Collect cache entries to save in a List<CacheEntry>
  Collect item results in a Map<Id, MatchingResult>

PHASE 2 — Cache saves (post-callout DML):
  Insert/upsert LLM_Response_Cache__c records

PHASE 3 — Item updates (final DML):
  Database.update(itemsToUpdate, false)
```

If any DML is introduced before the callout loop — even a single `insert` or `update` — the entire execution fails with `System.CalloutException: You have uncommitted work pending prior to callout`. Maintain this phase separation when extending the batch.

---

## Governor Limits

| Limit | Salesforce Cap | Strategy |
|---|---|---|
| Callouts per transaction | 100 | Process max 25 items per execution; hard-stop at 90 callouts |
| CPU time (Batch Apex) | 60 seconds | Hard-stop at 55,000ms; log warning if triggered |
| DML statements | 150 | Batch all item updates in a single `Database.update()` call |
| SOQL queries | 100 | Cache summary and factor set in constructor; minimize queries in `execute()` |

---

## Configuration

All scoring thresholds and LLM score mappings are stored in `LLM_Config__mdt` (Default record) and loaded once in the `BulkMatchingBatch` constructor. This means threshold changes take effect on the next job without any code redeployment. See [CONFIGURATION_GUIDE.md](../operations/CONFIGURATION_GUIDE.md) for the full field list and deploy instructions.

---

## Data Model

### Fields Updated on `Scope3PcmtItem`

| Field | Set when |
|---|---|
| `PcmtEmssnFctrSetItemId` | Score ≥ `Auto_Apply_Threshold__c` |
| `Match_Confidence_Score__c` | Always (if a result was produced) |
| `Match_Reasoning__c` | Always (if a result was produced) |
| `Match_Source__c` | Set to `'AI Suggested'` on auto-apply |
| `Review_Status__c` | `'Passed Confidence Match'` or `'Pending Review'` |

### Progress Fields on `Scope3PcmtSummary`

| Field | Purpose |
|---|---|
| `Bulk_Matching_Status__c` | `Not Started` / `In Progress` / `Complete` / `Error` |
| `Bulk_Matching_Job_Id__c` | Apex batch/queueable job ID |
| `Bulk_Matching_Completed_Date__c` | Timestamp set in `finish()` |
| `Bulk_Matching_Items_Processed__c` | Running total — updated each execution |
| `Bulk_Matching_Items_Matched__c` | Auto-applied high-confidence matches |
| `Bulk_Matching_Items_Needing_Review__c` | Items below threshold or with no match |
| `Bulk_Matching_Cache_Hits__c` | Items served from `LLM_Response_Cache__c` |
| `Bulk_Matching_Deduplicated__c` | Items served from in-memory map |
| `Bulk_Matching_LLM_Calls__c` | Actual Agentforce API invocations |

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Individual item fails | Log error to `Match_Reasoning__c`, mark `Pending Review`, continue with remaining items |
| Cache lookup fails | Log and continue — fall through to LLM call |
| Cache save fails | Log and continue — processing is not blocked |
| LLM call fails | Mark item `Pending Review`, increment `totalNeedsReview`, continue |
| Callout limit approached | Exit item loop early; remaining items process in the next batch execution |
| CPU limit approached | Exit item loop early with a warning log |
| Batch job fails entirely | `finish()` sets `Bulk_Matching_Status__c = 'Error'` |
