# Technical Architecture

## Executive Summary

Completing a spend-based Scope 3 greenhouse gas inventory in Net Zero Cloud requires mapping every procurement line item to an emissions factor from the USEEIO reference set — a 1,016-code library. The manual process does not scale: a 500-line spend file is 500 individual classification decisions. The USEEIO Matching Agent automates this classification pipeline by combining deterministic keyword pre-filtering with Einstein AI via Salesforce Prompt Builder, applying high-confidence matches automatically and routing low-confidence items to a human review queue.

This document describes the full architecture of the system: how it is structured, what each component does and why, where the critical design decisions live, what the system cannot do, and what must be true before it deploys. It is intended for the Salesforce architect or Net Zero Cloud senior admin responsible for implementing or extending this build.

**Covered in this document:** Scope and intentional exclusions · System limits and constraints · Human workflow · Component map · Anatomy walkthrough (three-stage pipeline, caching strategy, batch design, confidence model, Prompt Builder integration) · Gotchas and limitations · Deployment readiness checklist

---

## Scope

**Covered:** Apex service layer, batch and queueable infrastructure, Einstein Prompt Builder integration via `ConnectApi.EinsteinLLM`, caching layer (`LLM_Response_Cache__c`), custom object and field definitions, permission set, LWC single-item UI, and demo reset flow.

**Intentionally excluded:** Lightning page layout configuration, Net Zero Cloud base object schema (`Scope3PcmtItem`, `Scope3PcmtSummary`, `PcmtEmssnFctrSet`, `PcmtEmssnFctrSetItem` are standard NZC objects treated as read-mostly), org-level Einstein setup and Flex Credits provisioning, and integration with Data Cloud or external data pipelines.

---

## What It Cannot Do

**Prerequisite:** A deployed and configured Flex Prompt Template (`NAICS_Matching_Prompt`) with the correct API name is required before any LLM call will succeed. If the template is absent or the API name in `LLM_Config__mdt` does not match exactly, `LLMService.suggestNaicsCode()` returns an error and the item routes to the review queue rather than failing silently.

**Prerequisite:** The target `Scope3PcmtSummary` must have a factor set (`PcmtEmssnFctrId`) configured before bulk matching can start. `BulkMatchingQueueable` validates this and aborts with an error if missing.

**Constraint:** The system selects only from the 50 pre-filtered candidate NAICS codes. If the correct classification for a spending category is not in the top 50 keyword matches, the AI cannot select it — it is constrained by the system prompt to pick from the supplied list only. Items where none of the candidates are correct will land in the review queue with a low-confidence score; the sustainability manager must select the correct code manually.

**Constraint:** EEIO codes (United States Environmentally-Extended Input-Output codes, used in some emissions factor sets alongside NAICS codes) receive enhanced detection logic but are not excluded from the candidate set. Detection runs post-match, after a code is selected, and adjusts the confidence score downward. It does not prevent EEIO codes from being surfaced as candidates.

**Constraint:** The system does not learn or improve over time. A cached response is reused exactly — it does not accumulate feedback from human review decisions. If a sustainability manager overrides a low-confidence match, that override is not fed back into the model or the cache.

**Constraint:** Bulk matching processes items in batches of 25 with governor exit thresholds at 90 callouts or 55,000ms CPU time. Large inventories (500+ items) process across multiple batch executions. The `Scope3PcmtSummary` status fields track cumulative progress.

---

## What It Does

A sustainability manager opens a Scope 3 summary record in Net Zero Cloud. If unmatched spend items exist, they click "Run Bulk Matching." The system queues a batch job via `BulkMatchingQueueable`, which initializes progress tracking fields and hands off to `BulkMatchingBatch`. Each batch execution processes up to 25 items: checking the cache first, calling the AI only for uncached combinations, writing cache entries, and then applying matches. High-confidence matches (score ≥ `Auto_Apply_Threshold__c`, default `0.7`) are applied automatically with `Review_Status__c = 'Passed Confidence Match'`. Items scoring below threshold get `Review_Status__c = 'Pending Review'` and surface in a review queue for the manager.

For single-item matching, the `useeioMatcher` LWC on a `Scope3PcmtItem` record page exposes a "Find Emissions Factor" button that calls the same `USEEIOMatchingService` layer synchronously — useful for one-off re-matching or reviewing an alternative. After applying a match, the component immediately refreshes the record page so the linked emissions factor field updates inline without a manual page reload.

---

## Component Map

| Component | Type | Role |
|---|---|---|
| `USEEIOMatchingService.cls` | Apex Service | Main orchestration — coordinates keyword filtering, cache lookup, LLM call, factor resolution, confidence scoring, and record update for a single item |
| `LLMService.cls` | Apex Service | Invokes the Flex Prompt Template via `ConnectApi.EinsteinLLM`; parses JSON response; validates 6-digit NAICS format |
| `KeywordMatchingService.cls` | Apex Service | Deterministic pre-filter — scores all NAICS candidates by keyword overlap, returns top 50 |
| `LLMResponseCache.cls` | Apex Service | Reads and writes `LLM_Response_Cache__c`; manages cache key (SHA-256 hash of category combination + factor set ID) |
| `BulkMatchingBatch.cls` | Apex Batch (Stateful) | Processes items in batches of 25; manages deferred DML, in-memory deduplication, statistics tracking |
| `BulkMatchingQueueable.cls` | Apex Queueable | Async entry point — validates prerequisites, initializes `Scope3PcmtSummary` status, enqueues batch |
| `NAICS_Matching_Prompt` | Flex Prompt Template | Einstein AI prompt defining system role, candidate-selection constraint, and JSON output schema |
| `LLM_Config__mdt` | Custom Metadata Type | Runtime configuration — scoring thresholds, weights, template API name, and invocation application name |
| `LLM_Config.Default` | Custom Metadata Record | Default values for all configurable fields (see [CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md)) |
| `LLM_Response_Cache__c` | Custom Object | Persists LLM responses keyed on category hash + factor set ID |
| `Scope3PcmtItem` fields | Custom Fields | `Match_Confidence_Score__c`, `Match_Reasoning__c`, `Match_Source__c`, `Review_Status__c` |
| `Scope3PcmtSummary` fields | Custom Fields | Bulk matching status, job ID, progress counters |
| `useeioMatcher` | LWC | Single-item matching UI on `Scope3PcmtItem` record page |
| `Bulk_Matching_Access` | Permission Set | Grants Apex class access and CRUD on all matching-related objects |
| `NZC_USEEIO_EF_Matching_Agent_Reset_Demo_Flow` | Flow | Clears all matching results for a `Scope3PcmtSummary` — demo/testing use only |
| `MatchingResult.cls`, `AlternativeMatch.cls`, `BulkMatchingResult.cls`, `BulkMatchingStatus.cls` | Apex Wrappers | Typed return objects for service methods and `@AuraEnabled` endpoints |

---

## The Anatomy Walkthrough

The pipeline executes in three stages for every item. The stages are not interchangeable — Stage 1 (keyword filter) is a prerequisite for Stage 2 (AI), and Stage 2 determines the cache key for Stage 3 (resolution).

### Stage 1: Narrow the Field Before the AI Sees It

From `KeywordMatchingService.cls`, called at the top of `USEEIOMatchingService.matchSpendItemToFactorInternal()`:

```apex
List<KeywordMatchingService.ScoredCode> candidates =
    KeywordMatchingService.getTopCandidates(category1, category2, category3, 50);
```

The keyword service extracts terms from all three spending categories, removes stop words and tokens shorter than 3 characters, then scores all `PcmtEmssnFctrSetItem` records by keyword overlap against sector names and category descriptions. Exact matches in the sector description score 10 base points (industry keywords like "manufacturing" or "construction" score 20); exact matches in category description score 8; partial matches score 5. The top 50 by score are returned as candidates.

**Why:** The Flex Prompt Template's system prompt instructs the model to select only from the supplied candidate list. If the AI receives all 1,016 codes, response quality degrades and token consumption increases dramatically. The pre-filter concentrates the model's attention on plausible codes before it makes any decision.

**Gotcha:** If a spending category uses non-standard or jargon terminology that doesn't keyword-match against NAICS sector names (e.g., internal procurement labels like "Category 7 — Indirects"), the correct NAICS code may not appear in the top 50. The AI cannot compensate — it is constrained to the list. This is the system's primary classification failure mode and the most common reason for items landing in the review queue with "none of these match."

---

### Stage 2: The Most Important Pattern — Candidate Constraint in the System Prompt

From `NAICS_Matching_Prompt`, system prompt (verbatim):

```
If the candidate list is not empty and not 'None provided', you MUST pick
suggestedNaicsCode from that list only. Do not invent or substitute a
different 6-digit code outside the list.
```

**NON-NEGOTIABLE** — this is the most important pattern in this document. The candidate constraint is what makes the system safe to deploy: without it, the model may hallucinate plausible-looking NAICS codes that do not correspond to records in the customer's emissions factor set, producing a match reference to a code that does not exist in `PcmtEmssnFctrSetItem`. Such a match would silently return no emissions factor rather than surfacing an error. The constraint ensures the AI's suggestion is always a code that can be resolved downstream.

**Gotcha:** This constraint is enforced in the prompt, not in Apex. If the prompt template is replaced or modified without preserving this instruction, `findMatchingFactors()` will silently return an empty result for any hallucinated code and the item will be auto-rejected rather than auto-matched. The symptom is a sudden increase in "Pending Review" items with no AI reasoning. Verify the system prompt instruction is intact after any template change.

The prompt also defines the JSON output schema the model must return:

```json
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Concise justification using NAICS 2017 semantics",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

`LLMService.parseLLMResponse()` validates the returned code against a 6-digit numeric regex before accepting it. Markdown-fenced responses (where the model wraps the JSON in `` ```json `` blocks) are handled by stripping the fencing before parsing.

---

### Stage 3: Confidence Score Governs the Auto-Apply Decision

From `USEEIOMatchingService.calculateConfidenceScore()`:

```apex
Decimal score = (llmWeight       * llmScore)    // LLM_Weight__c (default 0.6)
              + (matchCountWeight * matchScore)  // Match_Count_Weight__c (default 0.2)
              + (factorSetWeight  * fsScore);    // Factor_Set_Weight__c (default 0.2)
```

The composite score governs whether a match is applied automatically. At or above `Auto_Apply_Threshold__c` (default `0.7`), `BulkMatchingBatch` applies the match and sets `Review_Status__c = 'Passed Confidence Match'`. Below threshold, the item is written with `Review_Status__c = 'Pending Review'` and no factor is applied.

The LLM confidence signal (`HIGH`/`MEDIUM`/`LOW`, mapped to `LLM_Score_High__c`/`LLM_Score_Medium__c`/`LLM_Score_Low__c`, defaults `0.9`/`0.6`/`0.3`) carries 60% of the score because it encodes the model's self-assessed uncertainty across the candidate set — the most information-dense signal available. Match count and factor set validation add specificity without over-relying on database state alone.

With default weights, the **maximum achievable score is 0.94** (LLM HIGH + single match + factor found). All scoring weights and thresholds are configurable via `LLM_Config__mdt` — no code change or redeployment required. See [CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md) for details.

---

### Caching: Deferred DML Prevents Mixed-DML Governor Failure

From `BulkMatchingBatch.cls`, the batch `execute()` method (summarized):

```apex
// PHASE 1: Dedupe + cache lookup — no DML
Map<String, MatchingResult> inMemoryDedupeMap = new Map<>();
List<CacheEntry> pendingSaves = new List<CacheEntry>();

// PHASE 2: LLM calls — callouts only, no DML
for (Scope3PcmtItem item : scope) {
    String hash = generateCategoryHash(item);
    if (inMemoryDedupeMap.containsKey(hash)) { /* reuse */ continue; }
    MatchingResult result = USEEIOMatchingService.matchSpendItemToFactorInternal(...);
    inMemoryDedupeMap.put(hash, result);
    pendingSaves.add(new CacheEntry(hash, result));
}

// PHASE 3: Cache save — post-callout DML
insert pendingSaves;

// PHASE 4: Item updates — final DML
Database.update(itemsToUpdate);
```

**Why:** Salesforce governor limits prohibit DML operations before a callout in the same transaction (the "You have uncommitted work pending" error). The batch separates callout phases from DML phases. Cache entries are collected in memory during the callout phase and written in a single DML operation afterward.

**Gotcha:** If this pattern is refactored to move any DML before the callout loop — even a single `insert` or `update` — the entire batch execution fails with `System.CalloutException: You have uncommitted work pending prior to callout`. The symptom is a complete batch execution failure with no partial results. Restore the deferred-DML pattern to fix.

---

### Prompt Builder Integration: Configuration Over Code

The template API name and invocation application name are read from `LLM_Config__mdt` at runtime rather than hardcoded. A Salesforce admin can swap the prompt template by editing the metadata record — no code change, no deployment required.

**Note:** The invocation application name (`PromptBuilderPreview` in the default record) must match a valid application context in the org. If this value is wrong, `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()` returns an authorization error. The symptom is a null or error response in `LLMService` that routes all items to the review queue. Verify the application name in the org's Einstein setup before first deployment.

Scoring thresholds (`Auto_Apply_Threshold__c`, LLM weights, LLM score mappings) are also stored in `LLM_Config__mdt` and loaded at runtime — once per `@AuraEnabled` transaction in the service layer, and once per batch job in `BulkMatchingBatch` (loaded in the constructor as instance variables; `Database.Stateful` carries them across all `execute()` chunks without repeated metadata queries).

---

## Gotchas and Limitations

| Gotcha | Details and Mitigation |
|---|---|
| Flex Credits consumed on every uncached call | Each call to `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()` consumes Einstein Flex Credits. NZC customers without a prior Einstein Add-On purchase will not have Flex Credits provisioned. Confirm availability with the AE before running bulk matching in production. The first bulk run is the most expensive; repeat runs on similar spend data are served from cache. |
| Keyword pre-filter is the system's accuracy ceiling | The AI can only select from the top 50 candidates. If the correct NAICS code is not in that set due to unusual spend category language, the system cannot find it. Review queue size increases with non-standard procurement taxonomy. Mitigation: normalize spending category labels before running bulk matching. |
| Candidate constraint is in the prompt, not Apex | If the system prompt is modified without preserving the candidate constraint, hallucinated codes will pass NAICS format validation but silently return no factor. Symptom: spike in "Pending Review" items with empty reasoning. Verify the constraint is intact after any template change. |
| EEIO code detection is post-match | EEIO detection runs after the AI selects a code, not before it generates candidates. EEIO codes reduce confidence but are not excluded from the candidate set. |
| `LLM_Config__mdt` queries `DeveloperName = 'Default'` | Only the record named `Default` is read. If renamed in a new org deployment, `LLMService` returns a null config and throws. |
| Demo reset flow is destructive | `NZC_USEEIO_EF_Matching_Agent_Reset_Demo_Flow` clears all matching data on every `Scope3PcmtItem` for the targeted summary with no confirmation guard. Do not deploy to production orgs, or restrict access via permission set exclusion. |
| System does not learn from human overrides | Cache entries are never updated based on review decisions. If a manager consistently overrides a cached match, the system will continue surfacing that match from cache until the cache record is manually deleted. |

---

## Deployment Readiness

| Component | Type | Must exist before |
|---|---|---|
| Einstein AI feature enabled in org | Org configuration | Any LLM call |
| Flex Credits provisioned | Org entitlement | Any LLM call; verify with AE |
| `NAICS_Matching_Prompt` Flex Template deployed and active | Prompt Builder metadata | `LLMService` invocation |
| `LLM_Config__mdt` object + all fields deployed | Custom Metadata | `LLMService`, `BulkMatchingBatch` config load |
| `LLM_Config.Default` metadata record deployed | Custom Metadata Record | `LLMService` — must have `DeveloperName = 'Default'` |
| `LLM_Response_Cache__c` object + fields deployed | Custom Object | Cache read/write in `LLMResponseCache.cls` |
| `Scope3PcmtItem` custom fields deployed | Field Metadata | `applyMatch()`, `USEEIOMatchingService` |
| `Scope3PcmtSummary` custom fields deployed | Field Metadata | `BulkMatchingQueueable`, progress tracking |
| `Bulk_Matching_Access` permission set deployed and assigned | Permission Set | All Apex class access and object CRUD |
| All Apex classes deployed | Apex | All functionality |
| `useeioMatcher` LWC deployed and added to `Scope3PcmtItem` page layout | LWC + Page Layout | Single-item matching UI |
| Net Zero Cloud base license with `Scope3PcmtItem` and `Scope3PcmtSummary` access | Org license | All functionality |

---

## Appendix: Quick Reference

### Custom Fields — `Scope3PcmtItem`

| API Name | Label | Notes |
|---|---|---|
| `Match_Confidence_Score__c` | Match Confidence Score | Number, 3 precision, 2 decimal. 0.0–1.0 |
| `Match_Reasoning__c` | Match Reasoning | Long Text. LLM explanation |
| `Match_Source__c` | Match Source | Picklist: AI Suggested, User Override, Manual Selection |
| `Review_Status__c` | Review Status | Picklist: Pending Review, Reviewed, Skipped, Passed Confidence Match |

### Custom Fields — `Scope3PcmtSummary` (Bulk Matching)

| API Name | Label | Notes |
|---|---|---|
| `Bulk_Matching_Status__c` | Bulk Matching Status | Picklist: Not Started, In Progress, Complete, Error |
| `Bulk_Matching_Job_Id__c` | Bulk Matching Job ID | Text — Apex batch/queueable job ID |
| `Bulk_Matching_Items_Processed__c` | Items Processed | Number |
| `Bulk_Matching_Items_Matched__c` | Items Matched | Number — auto-applied high-confidence only |
| `Bulk_Matching_Items_Needing_Review__c` | Items Needing Review | Number |
| `Bulk_Matching_Cache_Hits__c` | Cache Hits | Number |
| `Bulk_Matching_Deduplicated__c` | Deduplicated | Number — in-memory deduplication within batch |
| `Bulk_Matching_LLM_Calls__c` | LLM Calls | Number — actual Einstein API invocations |

### Custom Metadata — `LLM_Config__mdt` Fields

| API Name | Default | Purpose |
|---|---|---|
| `Prompt_Template_API_Name__c` | `NAICS_Matching_Prompt` | Developer name of the Flex template in Prompt Builder |
| `Prompt_Invocation_Application_Name__c` | `PromptBuilderPreview` | `applicationName` passed to `ConnectApi.EinsteinLLM` |
| `Auto_Apply_Threshold__c` | `0.7` | Minimum composite score for auto-apply |
| `LLM_Weight__c` | `0.6` | Weight of LLM confidence in composite score |
| `Match_Count_Weight__c` | `0.2` | Weight of match count in composite score |
| `Factor_Set_Weight__c` | `0.2` | Weight of factor set validation in composite score |
| `LLM_Score_High__c` | `0.9` | Raw score for LLM `HIGH` confidence |
| `LLM_Score_Medium__c` | `0.6` | Raw score for LLM `MEDIUM` confidence |
| `LLM_Score_Low__c` | `0.3` | Raw score for LLM `LOW` confidence |

### Cache Object — `LLM_Response_Cache__c`

| API Name | Label | Notes |
|---|---|---|
| `Category_Hash__c` | Category Hash | Text, 255, unique, external ID. SHA-256 of `"cat1\|cat2\|cat3"` |
| `Factor_Set_ID__c` | Factor Set ID | Text — part of composite key with `Category_Hash__c` |
| `Suggested_NAICS__c` | Suggested NAICS | Text — 6-digit code |
| `Confidence__c` | Confidence | Text — HIGH, MEDIUM, LOW |
| `Reasoning__c` | Reasoning | Long Text |
| `Alternative_NAICS_Codes__c` | Alternative NAICS Codes | Text — comma-separated |
| `Use_Count__c` | Use Count | Number — incremented on each cache hit |
| `Last_Used_Date__c` | Last Used Date | DateTime |

### Salesforce Documentation References

- [Prompt Builder Developer Guide](https://developer.salesforce.com/docs/einstein/genai/guide/prompt-builder.html)
- [ConnectApi.EinsteinLLM Documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_connectapi_EinsteinLLM.htm)
- [Apex Batch Processing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- [Custom Metadata Types](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/custommetadatatypes_overview.htm)
- [NAICS 2017 Reference](https://www.census.gov/naics/)
