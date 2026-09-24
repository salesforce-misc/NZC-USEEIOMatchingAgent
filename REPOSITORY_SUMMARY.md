# USEEIO Matching Agent — Repository Summary

**USEEIO Matching Agent** is a Salesforce DX project for **Net Zero Cloud** that automates the classification of procurement line items (`Scope3PcmtItem`) to USEEIO-style emissions factor rows (`PcmtEmssnFctrSetItem`) using **NAICS 2017**-oriented logic, deterministic keyword pre-filtering, an **LLM** invoked via **Prompt Builder**, and **response caching** on `LLM_Response_Cache__c`.

This file is the **primary orientation document** for humans and AI assistants working in this repo. Expand it as the solution grows.

## Canonical repository

**Canonical location:** [`salesforce-misc/NZC-USEEIOMatchingAgent`](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent) — the single source of truth.

> **All new development happens here.** The earlier repo `nicholaschughes/USEEIOMatchingAgent` was the initial development location; its history was merged in and it is no longer being synced from. There is intentionally **no `upstream` remote** configured — do not re-add one or attempt to pull from the old repo.

## Overview

Completing a spend-based Scope 3 emissions inventory requires mapping every line of procurement spend to the right emissions factor — choosing from hundreds of industry average emissions factors across the full USEEIO reference set. The manual process does not scale. The USEEIO Matching Agent automates this classification pipeline:

- **Keyword pre-filtering** (`KeywordMatchingService`) narrows the full set of 1,016 NAICS codes to the top 50 most likely candidates for each set of spending categories.
- **Agentforce** (`LLMService` via Prompt Builder) selects the single best match from those candidates and returns a confidence level and reasoning.
- **Confidence scoring** (`USEEIOMatchingService.calculateConfidenceScore`) computes a composite 0.0–1.0 score from the LLM confidence signal, match count, and factor set validation.
- **Auto-apply**: Items scoring at or above the configurable threshold (default `0.7`) are matched automatically. Items below threshold are queued for human review.
- **Response caching** (`LLMResponseCache`) persists LLM outputs keyed by spending category hash + factor set ID to eliminate repeated callouts on identical inputs.
- **In-batch deduplication**: Items with identical spending categories within a bulk run share a single LLM result in memory — no duplicate API calls.
- **Single-item and bulk paths**: The `useeioMatcher` LWC supports one-off matching directly from a procurement item record; `bulkMatchingSummary` + `BulkMatchingBatch` handle full-inventory runs asynchronously.
- **Configurable thresholds**: Auto-apply threshold, scoring weights, and LLM score mappings live in `LLM_Config__mdt` — adjustable without code redeployment.

## Technology stack

- **Salesforce DX** (`sfdx-project.json`), Apex, LWC, Jest (`sfdx-lwc-jest`), ESLint, Prettier, Husky.
- **Net Zero Cloud** standard objects: `Scope3PcmtItem`, `Scope3PcmtSummary`, `PcmtEmssnFctrSet`, `PcmtEmssnFctrSetItem`.
- **Agentforce / Prompt Builder**: `LLMService` invokes a **Flex Prompt Template** (`NAICS_Matching_Prompt`) via **`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`**. Template API name and invocation application name are read from `LLM_Config__mdt` at runtime. Default design uses **no Data Library grounding** — candidates and descriptions come from Apex; the model uses its NAICS 2017 knowledge to select from the supplied candidate list.
- **Agentforce Flex Credits**: Every LLM call that is not served from cache or deduplicated within a batch run consumes Agentforce Flex Credits. Confirm availability with the Salesforce AE before production use.

## Architecture (high level)

| Layer | Responsibility |
|---|---|
| LWC | UI only: call `@AuraEnabled` services, display status and results, review queues, lookups. No LLM callouts from the browser. |
| `USEEIOMatchingService` | Orchestration: queries, bulk entry points, match application, review queue helpers. Loads `LLM_Config__mdt` once per transaction via static cache. |
| `KeywordMatchingService` | Deterministic candidate NAICS from spending categories — top 50 by keyword overlap score. |
| `LLMService` | LLM call + JSON parse + NAICS format validation. Reads template config from `LLM_Config__mdt`. |
| `LLMResponseCache` | Cache CRUD for `LLM_Response_Cache__c`. Keyed by SHA-256 hash of `"cat1\|cat2\|cat3"` + factor set ID. |
| `BulkMatchingQueueable` | Validates summary prerequisites, initializes `Scope3PcmtSummary` status fields, starts batch job. |
| `BulkMatchingBatch` | Stateful batch (25 items/execution): in-memory dedupe, cache read, deferred DML, deferred cache write, item updates. Loads `LLM_Config__mdt` once in constructor — instance variables persist across all `execute()` calls via `Database.Stateful`. |
| `NAICS_Matching_Prompt` | Agentforce Prompt Builder Flex Template: receives candidate NAICS codes + descriptions from Apex, returns best-match code with confidence and reasoning as structured JSON. Candidate constraint in system prompt prevents hallucinated codes. |
| `LLM_Config__mdt` (Default record) | Runtime config: prompt template API name, invocation app name, auto-apply threshold, LLM score mappings, and scoring weights. |

## Key paths (`force-app/main/default`)

```
classes/
  USEEIOMatchingService.cls    — Main matching API (single, bulk start, status, review)
  LLMService.cls               — LLM invocation and response parsing
  LLMResponseCache.cls         — Cache get/save
  KeywordMatchingService.cls   — Candidate NAICS
  BulkMatchingBatch.cls        — Stateful batch (dedupe, cache, deferred DML, updates)
  BulkMatchingQueueable.cls    — Async kickoff and prerequisite validation
  MatchingResult.cls           — Single-item result DTO (@AuraEnabled properties)
  AlternativeMatch.cls         — Alternative candidate DTO (@AuraEnabled properties)
  BulkMatchingResult.cls       — Bulk run result DTO
  BulkMatchingStatus.cls       — Bulk run status DTO
  *Test.cls                    — Apex tests

lwc/
  useeioMatcher/               — Single-item matching UX on Scope3PcmtItem record page
  bulkMatchingSummary/         — Bulk run initiation and progress polling
  bulkMatchingSummaryModal/    — Review queue modal for low-confidence items
  factorSetItemLookup/         — Custom lookup filtered by factor set
  customDatatable/             — Datatable with inline lookup cell support

objects/
  LLM_Response_Cache__c/       — Cache object + fields
  LLM_Config__mdt/fields/      — Prompt template config + all scoring threshold fields
  Scope3PcmtSummary/fields/    — Bulk matching status, job ID, progress counters
  Scope3PcmtItem/fields/       — Match metadata (confidence, reasoning, source, review status)

customMetadata/
  LLM_Config.Default.md-meta.xml  — Default values for all LLM_Config__mdt fields

flows/
  NZC_USEEIO_EF_Matching_Agent_Reset_Demo_Flow  — Demo/sandbox reset only
```

## Documentation map

- [TECHNICAL_ARCHITECTURE.md](documentation/operations/TECHNICAL_ARCHITECTURE.md) — Full architecture reference: three-stage pipeline walkthrough, caching design, governor limit patterns, confidence scoring model, deployment readiness checklist, and field-level appendix
- [CONFIGURATION_GUIDE.md](documentation/operations/CONFIGURATION_GUIDE.md) — How to adjust scoring thresholds and swap the prompt template via `LLM_Config__mdt` without a code redeployment
- [PERMISSIONS_CHECKLIST.md](documentation/operations/PERMISSIONS_CHECKLIST.md) — Permission set and FLS checklist for deploying to a new org
- [CALL_PROMPT_TEMPLATE.md](documentation/llm-integration/CALL_PROMPT_TEMPLATE.md) — How `LLMService` invokes the Flex template via `ConnectApi.EinsteinLLM`; Apex pattern and input variable reference
- [BULK_MATCHING_DESIGN.md](documentation/architecture/BULK_MATCHING_DESIGN.md) — Design rationale for the batch + queueable architecture
- [BULK_PROCESSING_FLOW_WITH_CACHING.md](documentation/architecture/BULK_PROCESSING_FLOW_WITH_CACHING.md) — Step-by-step flow of the deferred-DML caching pattern used in `BulkMatchingBatch`

## Development workflow

`main` is **protected**. All changes land via PR with at least one approving CODEOWNER review (see [CONTRIBUTING.md](./CONTRIBUTING.md) for the full policy).

1. `git checkout -b feat/short-description` off the latest `main`.
2. Change metadata under `force-app/main/default/`.
3. Deploy locally: `sf project deploy start` (or VS Code Salesforce extensions).
4. Run Apex tests: `sf apex run test --test-level RunLocalTests`.
5. LWC unit tests: `npm run test:unit`.
6. Push branch and open a PR against `main`; request review from a CODEOWNER.
7. Merge with **squash** or **rebase** (linear history required; merge commits are blocked).

## External references

- [Invoke prompt templates from Apex](https://developer.salesforce.com/blogs/2024/04/invoke-prompt-templates-from-flow-apex-or-the-rest-api) — `ConnectApi.EinsteinLLM` pattern
- [Apex Batch Processing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- [Custom Metadata Types](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/custommetadatatypes_overview.htm)
- [NAICS 2017 Reference](https://www.census.gov/naics/)
