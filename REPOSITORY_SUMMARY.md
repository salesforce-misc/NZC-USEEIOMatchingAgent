# Repository Summary

> **Purpose:** LLM-optimized orientation document for the `USEEIOMatchingAgent` repository. Single source of truth for project structure, architecture, components, and workflows. Read this first per `.cursor/rules copy/repo-shape.mdc`.

---

## 1. Overview

**Project name:** USEEIO Matching Agent
**Type:** Salesforce DX project (Net Zero Cloud extension)
**Purpose:** AI-powered matching service that classifies free-text spending categories on `Scope3PcmtItem` records and links them to the correct `PcmtEmssnFctrSetItem` emissions factor via **NAICS 2017** industry codes, drawing on the **USEEIO v2.0** environmentally-extended input-output model (Ingwersen et al., 2022).

**Current state:** Design / pre-implementation phase. The repo contains scaffolding (Salesforce DX configs, lint/test tooling, Cursor rules) and a large body of architecture documentation. **No Apex classes, LWC components, or metadata have been authored yet** (no `force-app/` directory exists).

**Domain primer (cite when reasoning):**
- USEEIO v2.0 — US environmental-economic LCA model, base year 2012, environmental data 2014–2017, 411 BEA commodity categories, multiple matrices (D, N, H_r, H_f), domestic/foreign and producer/purchaser price variants.
- NAICS 2017 — Hierarchical 6-digit industry classification (Sector → Subsector → Industry Group → Industry → U.S. Industry); ~1,016 6-digit codes are the matching key.

---

## 2. Technology Stack

| Layer | Technology |
|---|---|
| Platform | Salesforce (Net Zero Cloud) |
| Build/CLI | Salesforce DX (`sfdx-project.json`, `sourceApiVersion: 65.0`) |
| Backend logic | Apex (planned — service classes, wrappers, async jobs) |
| UI | Lightning Web Components (LWC) + optional Screen Flow |
| AI | Agentforce + LLM Open Connector / BYO LLM with RAG grounding |
| Reference data | Custom Metadata Type `NAICS_Definition__mdt` *or* Agentforce Data Library PDF |
| Testing | `@salesforce/sfdx-lwc-jest` (Jest for LWC) |
| Lint/Format | ESLint (`@salesforce/eslint-config-lwc`, aura, lightning), Prettier + `prettier-plugin-apex`, `@prettier/plugin-xml` |
| Git hooks | Husky + lint-staged (runs prettier, eslint, and `sfdx-lwc-jest` related tests on commit) |

---

## 3. Architecture (Planned)

```
┌────────────────────── UI Layer ──────────────────────┐
│   LWC: useeioMatcher (record page on Scope3PcmtItem) │
│   Screen Flow: Match_Spend_Item_to_Factor (optional) │
└──────────────────────────┬───────────────────────────┘
                           │
┌──────────────── Service Layer (Apex) ────────────────┐
│   USEEIOMatchingService                              │
│     • matchSpendItemToFactor(Id)                     │
│     • analyzeSpendingCategories(c1,c2,c3)            │
│     • findMatchingFactors(naics, scope3ItemId)       │
│     • calculateConfidenceScore(...)                  │
│     • applyMatch(itemId, factorId, score)            │
│   Wrappers: MatchingResult, AlternativeMatch         │
│   Async: Queueable/Batchable (bulk phase 2)          │
└──────────────────────────┬───────────────────────────┘
                           │
┌────────────── LLM Integration Layer ─────────────────┐
│   LLMService (LLM Open Connector / BYO LLM)          │
│   • Two-stage flow: keyword pre-filter → LLM with    │
│     full NAICS context → JSON-structured response    │
│   • Grounding sources (alternatives):                │
│     - Custom Metadata NAICS_Definition__mdt          │
│     - Agentforce Data Library (NAICS PDF, RAG)       │
└──────────────────────────┬───────────────────────────┘
                           │
┌──────────────────── Data Layer ──────────────────────┐
│  Scope3PcmtItem ──(populates)──> PcmtEmssnFctrSetItem│
│  (Spend record)                    (Emissions factor)│
└──────────────────────────────────────────────────────┘
```

**Matching flow:** Extract spend categories → Stage 1 keyword pre-filter to top 30–50 NAICS candidates → Stage 2 LLM call with rich NAICS definitions → Query `PcmtEmssnFctrSetItem` by `EconomicSectorCode` scoped to parent `PcmtEmssnFctrSetId` (resolved via `Scope3PcmtSummary.PcmtEmssnFctrId`) → Score confidence → Return result with alternatives.

---

## 4. Data Model

### Standard Net Zero Cloud objects (referenced)

**`Scope3PcmtItem`** (source / spend data)
- `SpendingCategory1/2/3` — free-text inputs to AI
- `PcmtEmssnFctrSetItemId` — **target lookup** populated by the agent
- `SupplierId`, `ProductId`, `Scope3GhgCategory`, `SpentAmount`, `SpentDate`
- `CalculatedScope3EmssnInTco2e` (formula)

**`PcmtEmssnFctrSetItem`** (target / emissions factors)
- `EconomicSectorCode` (Text 255) — **NAICS code; the matching key**
- `EconomicSector`, `EconomicSectorCategory`
- `TotScpe3EmssnPerMillionSpent` (tCO2e per million USD)
- `Scope3GhgCategory`, `Region`
- `PcmtEmssnFctrSetId` — master-detail to factor set (scoping constraint)

**`Scope3PcmtSummary`** — bridge: `ProcurementSummaryId` → `PcmtEmssnFctrId` (identifies the in-scope `PcmtEmssnFctrSet`).

### Planned custom additions

**Custom fields on `Scope3PcmtItem`:**
- `Match_Confidence_Score__c` — Number(3,2)
- `Match_Reasoning__c` — Long Text (32,768)
- `Match_Source__c` — Picklist {AI Suggested, User Override, Manual Selection}

**Custom Metadata Type `NAICS_Definition__mdt`:**
`Code__c` (External ID), `Title__c`, `Description__c`, `Sector__c`, `Subsector__c`, `Industry_Group__c`, `Industry__c`, `Cross_References__c`, `Illustrative_Examples__c`, `Keywords__c`, `Full_Definition__c`.

---

## 5. Key Features

1. **Single-item matching (POC, Phase 1)** — LWC on `Scope3PcmtItem` record page with confidence indicator, alternatives, and Apply/Retry/Manual actions.
2. **Bulk processing (Phase 2)** — List-view bulk matcher backed by Queueable/Batchable Apex with progress tracking, confidence-bucketed review.
3. **Two-stage LLM grounding** — Keyword pre-filter → LLM with full NAICS definitions to stay under token limits while preserving accuracy.
4. **Confidence scoring** — Weighted blend of LLM confidence, match count, and factor-set validation.
5. **Audit trail** — `Match_Source__c`, `Match_Reasoning__c`, score history.
6. **Pluggable grounding** — Custom Metadata *or* Agentforce Data Library PDF (Knowledge Grounding via RAG).

---

## 6. Directory Structure

```
USEEIOMatchingAgent/
├── .cursor/
│   ├── rules                     # FILE (USEEIO/NAICS system context) — NOTE: should be a directory
│   └── rules copy/               # Cursor .mdc rules (currently not loaded by Cursor due to folder name)
│       ├── repo-shape.mdc        # THIS rule — read REPOSITORY_SUMMARY.md first
│       ├── Accelerator README.mdc
│       ├── Apex Rules.mdc
│       ├── apex-best-practices.mdc
│       ├── lwc-best-practices.mdc
│       ├── lwc-jest-tests.mdc
│       ├── lwc-jest-tests-sfdc.mdc
│       ├── OSPO-Comppliance.mdc
│       └── Salesforce Quality.mdc
├── .husky/                       # Git hooks (pre-commit → lint-staged)
├── .sfdx/                        # Local SFDX state
├── .vscode/                      # Editor settings
├── config/
│   └── project-scratch-def.json  # Developer edition scratch org template ("n.hughes company")
├── scripts/
│   ├── apex/hello.apex           # Placeholder anonymous Apex
│   └── soql/account.soql         # Placeholder SOQL
├── force-app/                    # ❗ DOES NOT YET EXIST — default package directory per sfdx-project.json
├── sfdx-project.json             # API v65.0, default package = force-app
├── package.json                  # npm scripts (lint, test:unit, prettier), devDeps
├── eslint.config.js              # Flat ESLint config
├── jest.config.js                # LWC Jest config
├── .forceignore                  # Excludes package.xml, jsconfig.json, .eslintrc.json, __tests__
├── .prettierrc / .prettierignore
├── .gitignore / .gitattributes
├── README.md                     # Brief project intro + SFDX boilerplate
└── *.md (design docs — see §8)
```

---

## 7. Development Standards & Workflows

**Scripts (`package.json`):**
- `npm run lint` — ESLint over `aura/` and `lwc/` JS
- `npm run test` / `test:unit` / `test:unit:watch` / `test:unit:debug` / `test:unit:coverage` — `sfdx-lwc-jest`
- `npm run prettier` / `prettier:verify` — formats Apex, LWC, XML, markdown, etc.
- `npm run prepare` — installs Husky

**Pre-commit (lint-staged):**
- Prettier on `{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}`
- ESLint on `aura/` + `lwc/` JS
- `sfdx-lwc-jest -- --bail --findRelatedTests --passWithNoTests` on LWC changes

**Cursor rules in scope (see `.cursor/rules copy/`):**
- `Apex Rules.mdc` / `apex-best-practices.mdc` — Apex coding standards
- `lwc-best-practices.mdc`, `lwc-jest-tests*.mdc` — LWC + Jest standards
- `Salesforce Quality.mdc`, `OSPO-Comppliance.mdc` — quality & compliance
- `repo-shape.mdc` — this orientation directive (requires JSON output)

⚠️ **Cursor rule loading issue:** `.cursor/rules` is currently a *file*, while rules live in `.cursor/rules copy/`. Cursor expects `.cursor/rules/` to be a directory; rules are therefore not auto-loaded today. Recommend resolving before relying on rule enforcement.

---

## 8. Documentation Index (Design Phase)

| File | Lines | Purpose |
|---|---:|---|
| `README.md` | 40 | Project intro + SFDX boilerplate |
| `SOLUTION_DESIGN.md` | 577 | **Authoritative end-to-end design** — components, methods, prompts, confidence formula, phases, edge cases |
| `NZC_DATA_MODEL_ANALYSIS.md` | 169 | NZC object/field-level data model & open questions |
| `LLM_GROUNDING_STRATEGY.md` | 350 | Strategy for grounding LLM with NAICS context |
| `ENHANCED_LLM_GROUNDING.md` | 439 | Custom Metadata-based grounding (preferred for code-deploy path) |
| `AGENTFORCE_GROUNDING_APPROACH.md` | 301 | Alternative: Agentforce Data Library (PDF) RAG grounding |
| `DATA_LIBRARY_REFERENCE_SYNTAX.md` | 233 | How to reference Data Library / Knowledge Grounding in prompts |
| `NAICS_KNOWLEDGE_BASE.md` | 209 | NAICS 2017 reference for LLM/devs |
| `USEEIO_KNOWLEDGE_BASE.md` | 264 | USEEIO v2.0 reference (Ingwersen et al., 2022) |
| `DESIGN_BEST_PRACTICES.md` | 302 | General design guidance |
| `SALESFORCE_BEST_PRACTICES.md` | 215 | Salesforce-specific best practices |
| `CONNECTION_FIX.md` | 61 | Misc operational note |

---

## 9. External Dependencies & Integrations

- **Salesforce Net Zero Cloud** — standard objects (`Scope3PcmtItem`, `Scope3PcmtSummary`, `PcmtEmssnFctrSetItem`, `PcmtEmssnFctrSet`).
- **Agentforce** — agent/prompt builder; optional Data Library for PDF grounding.
- **LLM provider** — via LLM Open Connector / BYO LLM (OpenAI, Anthropic, etc.) returning structured JSON.
- **NAICS 2017 Definition File** (PDF) — source dataset for grounding (uploaded to Data Library *or* parsed into Custom Metadata).
- **USEEIO v2.0** — referenced model (no live integration; concepts inform design).

---

## 10. Open Questions / Decisions Pending

(From `NZC_DATA_MODEL_ANALYSIS.md` §"Questions for Clarification" — resolve before implementation)
1. Are spending categories free-form or picklist-controlled?
2. Should `SupplierId`/`ProductId`/`Scope3GhgCategory` factor into matching?
3. Volume & UX: bulk vs. interactive; auto-approval thresholds.
4. Hierarchical NAICS fallback (`SOLUTION_DESIGN.md` notes only 6-digit codes exist, so no fallback — confirm).
5. Grounding source choice: Custom Metadata vs. Agentforce Data Library (or both).
6. Integration with NZC calculation engine and approval workflows.

---

## 11. How to Use This Document (per `repo-shape.mdc`)

1. **READ_FILE** `REPOSITORY_SUMMARY.md` (this file) to establish baseline context.
2. **INVOKE_TOOLS** (`codebase_search`, `grep`, `read_file`) to deep-dive into the specific design doc or component named above.
3. **EXECUTE_TASK** with informed context. Return JSON per the template in `repo-shape.mdc` when the user query concerns project structure, architecture, components, data model, or workflow.

