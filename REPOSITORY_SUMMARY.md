# USEEIO Matching Agent — Repository Summary

**USEEIO Matching Agent** is a Salesforce DX project for **Net Zero Cloud** that matches procurement line items (`Scope3PcmtItem`) to **USEEIO-style** emissions factor rows (`PcmtEmssnFctrSetItem`) using **NAICS 2017**-oriented logic, keyword pre-filtering, an **LLM** (Models API today; migration to **Prompt Builder** planned), and **response caching** on `LLM_Response_Cache__c`.

This file is the **primary orientation document** for humans and AI assistants working in this repo (pattern recommended by the [Salesforce EMU DX template](https://github.com/jvillalpando_sfemu/LLM-Based-SalesforceProject)). Expand it as the solution grows.

## Canonical repository

**Canonical location:** [`salesforce-misc/NZC-USEEIOMatchingAgent`](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent) — the single source of truth.

> **All new development happens here.** The earlier repo `nicholaschughes/USEEIOMatchingAgent` was the initial development location; its history was merged in and it is no longer being synced from. There is intentionally **no `upstream` remote** configured — do not re-add one or attempt to pull from the old repo. Contributors who previously worked in the old repo must push directly to this repo (request collaborator access if needed).

## Overview

- Single-item and **bulk** matching from a **Procurement Summary** (`Scope3PcmtSummary`), with batch/queueable processing and progress fields on the summary.
- **KeywordMatchingService** narrows candidate NAICS codes; **LLMService** suggests a code; **USEEIOMatchingService** resolves factors, confidence, EEIO-vs-NAICS handling, and applies matches.
- **LLMResponseCache** persists LLM outputs keyed by category hash and factor set to reduce callouts and cost.
- LWCs support interactive matching, bulk run UI, factor lookup, and custom datatable patterns.

## Technology stack

- **Salesforce DX** (`sfdx-project.json`), Apex, LWC, Jest (`sfdx-lwc-jest`), ESLint, Prettier, Husky.
- **Net Zero Cloud** standard objects: `Scope3PcmtItem`, `Scope3PcmtSummary`, `PcmtEmssnFctrSet`, `PcmtEmssnFctrSetItem`.
- **Einstein / Agentforce**: `LLMService` invokes a **Prompt Builder** Flex template via **`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`** (template name from `LLM_Config__mdt`). Default design uses **no Data Library grounding**—candidates + descriptions from Apex and model NAICS knowledge; cache in `LLM_Response_Cache__c` is checked in Apex before LLM calls. See `documentation/llm-integration/PROMPT_BUILDER_SETUP.md` and `documentation/llm-integration/CALL_PROMPT_TEMPLATE.md`.

## Architecture (high level)

| Layer | Responsibility |
| ----- | ---------------- |
| LWC | UI only: call `@AuraEnabled` services, show status, review queues, lookups. |
| `USEEIOMatchingService` | Orchestration: queries, bulk entry points, match application, review helpers. |
| `KeywordMatchingService` | Deterministic candidate NAICS from spending categories. |
| `LLMService` | LLM call + JSON parse + NAICS validation. |
| `LLMResponseCache` | Cache CRUD for `LLM_Response_Cache__c`. |
| `BulkMatchingQueueable` | Validates summary, sets status, starts batch job. |
| `BulkMatchingBatch` | Stateful batch: dedupe, cache read, callouts, deferred cache write, DML updates. |

## Key paths (`force-app/main/default`)

```
classes/
  USEEIOMatchingService.cls    — Main matching API (single, bulk start, status, review)
  LLMService.cls               — LLM invocation and response parsing
  LLMResponseCache.cls         — Cache get/save
  KeywordMatchingService.cls   — Candidate NAICS
  BulkMatchingBatch.cls        — Batch execution (caching, dedupe, updates)
  BulkMatchingQueueable.cls    — Async kickoff
  MatchingResult.cls, AlternativeMatch.cls, BulkMatchingResult.cls, BulkMatchingStatus.cls
  *Test.cls                    — Apex tests

lwc/
  useeioMatcher/               — Single-item matching UX
  bulkMatchingSummary/         — Bulk run + polling
  bulkMatchingSummaryModal/    — Summary modal
  factorSetItemLookup/         — Factor lookup
  customDatatable/             — Datatable + lookup cell template

objects/
  LLM_Response_Cache__c/       — Cache object + fields
  LLM_Config__mdt/             — Prompt template API name + Connect invocation app name
  Scope3PcmtSummary/fields/    — Bulk matching custom fields (e.g. status, counts)
  Scope3PcmtItem/fields/     — Match metadata, review status
```

## Documentation map

| Topic | Document |
| ----- | -------- |
| Salesforce + EMU-aligned standards | [SALESFORCE_BEST_PRACTICES.md](documentation/standards/SALESFORCE_BEST_PRACTICES.md) |
| Bulk design | [BULK_MATCHING_DESIGN.md](documentation/architecture/BULK_MATCHING_DESIGN.md), [BULK_PROCESSING_FLOW_WITH_CACHING.md](documentation/architecture/BULK_PROCESSING_FLOW_WITH_CACHING.md) |
| Prompt Builder / Connect API | [PROMPT_BUILDER_SETUP.md](documentation/llm-integration/PROMPT_BUILDER_SETUP.md), [CALL_PROMPT_TEMPLATE.md](documentation/llm-integration/CALL_PROMPT_TEMPLATE.md) |
| LLM setup | [LLM_INTEGRATION_SETUP.md](documentation/llm-integration/LLM_INTEGRATION_SETUP.md), [QUICK_START_LLM.md](documentation/llm-integration/QUICK_START_LLM.md) |
| Domain | [NAICS_KNOWLEDGE_BASE.md](documentation/reference/NAICS_KNOWLEDGE_BASE.md), [USEEIO_KNOWLEDGE_BASE.md](documentation/reference/USEEIO_KNOWLEDGE_BASE.md) |
| Testing | [TESTING_STRATEGY.md](documentation/testing/TESTING_STRATEGY.md), [SANDBOX_TESTING_PLAN.md](documentation/testing/SANDBOX_TESTING_PLAN.md) |
| Known issues | [ISSUE_DESCRIPTION_FOR_EXPERTS.md](documentation/implementation/ISSUE_DESCRIPTION_FOR_EXPERTS.md) |

## Development workflow

1. Change metadata under `force-app/main/default/`.
2. Deploy: `sf project deploy start` (or VS Code/Cursor Salesforce extensions).
3. Run Apex tests: `sf apex run test --test-level RunLocalTests` (or scoped).
4. LWC unit tests: `npm run test:unit`.

## External references

- [Salesforce EMU LLM-Based-SalesforceProject (template)](https://github.com/jvillalpando_sfemu/LLM-Based-SalesforceProject) — DX layout, `REPOSITORY_SUMMARY.md` convention, Cursor rules for Apex/LWC.
- [Invoke prompt templates from Apex](https://developer.salesforce.com/blogs/2024/04/invoke-prompt-templates-from-flow-apex-or-the-rest-api) — `ConnectApi.EinsteinLLM` pattern.
