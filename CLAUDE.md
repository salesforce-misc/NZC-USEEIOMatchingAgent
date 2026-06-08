# Claude Code Instructions for Salesforce Projects

## Overview

This template is configured for both **Cursor IDE** and **Claude Code**. All coding standards, best practices, and architectural rules are shared between both tools.

**Note**: This file originated from the `sf-ai-starter-kit`. The `🏗️ Project-Specific Context` and `📦 Salesforce Integration` sections have been customized for **USEEIO Matching Agent**; the rest is generic Salesforce / LWC / Apex guidance shared across accelerators.

---

## 🎯 Primary Resources (Read First)

### 1. Repository Summary

**File**: [REPOSITORY_SUMMARY.md](./REPOSITORY_SUMMARY.md)  
**Purpose**: Complete project overview, architecture, data model, and component relationships

**⚠️ CRITICAL**: Always read this file first when:

- Starting any new task
- User asks about project structure or architecture
- Planning code changes or new features
- Need to understand component dependencies

### 2. Shared Rules Directory

**Location**: [.cursor/rules/](./.cursor/rules/)  
**Purpose**: Comprehensive coding standards and best practices

All rules in `.cursor/rules/` apply to both Cursor and Claude Code. These include:

- [repo-shape.mdc](./.cursor/rules/repo-shape.mdc) - Repository structure and workflow
- [lwc-best-practices.mdc](./.cursor/rules/lwc-best-practices.mdc) - LWC coding standards
- [Apex Rules.mdc](./.cursor/rules/Apex%20Rules.mdc) - Apex Enterprise Patterns (fflib)
- [apex-best-practices.mdc](./.cursor/rules/apex-best-practices.mdc) - Additional Apex guidelines
- [lwc-jest-tests.mdc](./.cursor/rules/lwc-jest-tests.mdc) - Jest testing standards
- [Accelerator README.mdc](./.cursor/rules/Accelerator%20README.mdc) - Documentation standards
- [OSPO-Comppliance.mdc](./.cursor/rules/OSPO-Comppliance.mdc) - Open source compliance

---

## 🛠️ Available Skills

Skills are interactive workflows that guide you through complex tasks. Invoke them using `/skillname` or by describing the task.

### `/readme-generate` - README Generator

Generate or update OSPO-compliant README files for Salesforce accelerators.

**When to use**:

- Creating new README from scratch
- Updating existing README sections
- Ensuring OSPO compliance (disclaimer, three installation paths)
- Formatting badges, diagrams, and architecture sections

**What it does**:

- Asks for project details (name, description, features)
- Generates complete README following Salesforce accelerator template
- Validates required sections (Quick Deploy, Features, Installation, Architecture)
- Ensures three installation paths (GitHub Deploy, Workbench, CLI)
- Adds OSPO-compliant disclaimer

**Reference**: Based on [Accelerator README.mdc](./.cursor/rules/Accelerator%20README.mdc)

### `/prepare-opensource` - Open Source Preparation

Validate OSPO compliance and prepare repository for public open source release.

**When to use**:

- Preparing accelerator for public GitHub release
- Checking OSPO compliance requirements
- Generating compliance files (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY)
- Scanning for internal Salesforce references
- Adding copyright headers to source files

**What it does**:

- Checks for required compliance files at root level
- Generates missing files from Salesforce OSS templates
- Scans for internal references (\*.sfdc.sh, internal tools)
- Adds copyright headers to all source files (.cls, .js, .html, .css)
- Creates compliance checklist
- Guides through approval process

**Reference**: Based on [OSPO-Comppliance.mdc](./.cursor/rules/OSPO-Comppliance.mdc)

**Note**: Skills reference the same standards from `.cursor/rules/` but provide interactive workflows for complex multi-step processes.

---

## 📋 Coding Standards

### Lightning Web Components (LWC)

**Reference**: [lwc-best-practices.mdc](./.cursor/rules/lwc-best-practices.mdc)

#### Naming Conventions

- **PascalCase** for component class names and folders
- **camelCase** for variables, methods, tracked properties
- Add descriptive suffixes: `Modal`, `Form`, `List`, `Step`

#### Code Organization

- Use Lightning base components whenever possible
- Break large methods into smaller, focused functions
- Use helper modules for reusable logic
- Comment only to explain _why_, not _what_

#### Reactivity & Functions

- Use `async/await` for better readability
- Check for `null`/`undefined` to avoid crashes
- Use `@api` only for externally accessed properties
- Use `@wire` for reactive data and handle errors
- Reassign entire objects to trigger reactivity: `this.obj = { ...this.obj }`

#### Styling & SLDS

- Use SLDS utility classes for layout and spacing
- Avoid inline styles; use component's CSS file
- Use SLDS design tokens (no hardcoded values)
- Add accessibility classes and ARIA attributes
- **When adding custom styles, do not use SLDS utility classes** - define your own CSS classes

#### Error Handling

- Handle wire service errors using `error` parameter
- Use `try/catch` in async logic
- Show errors using `ShowToastEvent`
- Always handle promise rejections

#### Security

- Never use `innerHTML` or direct DOM access (`document`, `window`)
- Avoid executing arbitrary code patterns
- Never store sensitive data in `localStorage`/`sessionStorage`
- Validate all `@api` inputs and message payloads

#### Testing

**Reference**: [lwc-jest-tests.mdc](./.cursor/rules/lwc-jest-tests.mdc)

- Aim for >85% code coverage
- Write Jest tests for public methods and UI states
- Mock wire calls in tests
- Structure: Arrange → Act → Assert
- Test errors, loading states, and edge cases
- **Do not assert on component properties** - verify DOM elements, attributes, text, and emitted events only

### Apex Standards

**References**:

- [Apex Rules.mdc](./.cursor/rules/Apex%20Rules.mdc) - fflib patterns
- [apex-best-practices.mdc](./.cursor/rules/apex-best-practices.mdc) - General guidelines

#### Architecture (fflib Patterns)

**Note**: This project currently uses a **simplified architecture** for read-only operations. Full fflib patterns should be applied if adding DML functionality.

**Layering** (when applicable):

- **Selector layer**: One Selector per SObject, encapsulates all SOQL
- **Service layer**: Orchestrates use cases, uses UnitOfWork for DML
- **Controller layer**: Thin façade calling Services

**Current Project Architecture**:

- Direct controller queries (no Selectors) - acceptable for read-only
- No Service layer - acceptable for read-only
- No UnitOfWork - no DML operations present

**If extending with DML**, follow full fflib:

```apex
// Selector pattern
public inherited sharing class AccountSelector extends fflib_SObjectSelector {
    public override Schema.SObjectType getSObjectType() {
        return Account.SObjectType;
    }
    // ... implement methods
}

// Service pattern
public with sharing class AccountService {
    private final fflib_ISObjectUnitOfWork unitOfWork;

    public void upsertAccounts(List<Account> accounts) {
        unitOfWork.registerUpsert(accounts);
        unitOfWork.commitWork();
    }
}

// Controller pattern
public with sharing class AccountController {
    @AuraEnabled
    public static void upsertAccounts(List<Account> accounts) {
        AccountService.newInstance().upsertAccounts(accounts);
    }
}
```

#### Apex Best Practices

**Reference**: [apex-best-practices.mdc](./.cursor/rules/apex-best-practices.mdc)

**Key Mindsets**:

1. **Testability**: Ensure code is easy to test
2. **Simplicity**: Less code is better (unless it hurts readability)
3. **Readability**: Use well-named variables/functions, don't be clever
4. **Performance**: Keep in mind but don't over-optimize
5. **Maintainability**: Write code that's easy to update
6. **Reusability**: Write reusable classes and methods

**Code Guidelines**:

- **Async Work**: Use Queueables with `System.Finalizer`, never `@future`
- **Null Objects**: Prefer Null Object pattern over nested conditionals
- **Variable Names**: Don't append type to collection names. Maps: use `idToAccount`, `accountIdToOpportunities`
- **Enums Over Strings**: Prefer enums (ALL_CAPS_SNAKE_CASE)
- **Repositories/Selectors**: Centralize DML and queries for testability
- **Task Focus**: Don't modify unrelated code

**Comments**: Don't over-comment. Prefer well-named variables/functions. Save comments for unidiomatic choices or platform oddities.

**Class Organization**: Follow "newspaper" rule - methods appear in order they're referenced. Alphabetize dependencies, fields, properties.

#### Security

- All queries must use `WITH USER_MODE` to enforce CRUD/FLS
- Use `with sharing` for controllers and services
- Use `inherited sharing` for selectors
- Validate inputs, handle exceptions with specific exception types
- No hardcoded IDs

#### Testing

- Coverage: >75% minimum, >85% preferred
- Use `fflib_ApexMocks` for interaction tests
- Test bulk scenarios (200+ records)
- Arrange-Act-Assert structure
- No `SeeAllData=true`
- Test factories/builders for test data
- Assert no SOQL/DML in loops

---

## 🔄 Workflow

### Step 1: Understand Context

1. Read [REPOSITORY_SUMMARY.md](./REPOSITORY_SUMMARY.md) first
2. Review relevant rules from [.cursor/rules/](./.cursor/rules/)
3. Understand component relationships and data flow

### Step 2: Plan Changes

1. **Create feature branch** - For new features or significant changes, create a branch following the naming convention:
   - `feature/descriptive-name` for new features
   - `bugfix/issue-description` for bug fixes
   - `refactor/area-name` for refactoring work
   - `docs/update-description` for documentation changes
2. Identify affected components
3. Consider impact on architecture
4. Plan test coverage updates
5. Verify against coding standards

### Step 3: Implement

1. Follow naming conventions
2. Maintain test coverage (>85%)
3. Add comments only where necessary
4. Update documentation if needed

### Step 4: Verify

1. Run tests (Jest for LWC, Apex tests)
2. Verify code coverage
3. Check against best practices
4. Ensure no security issues

---

## 🏗️ Project-Specific Context

**Repository:** [`salesforce-misc/NZC-USEEIOMatchingAgent`](https://github.com/salesforce-misc/NZC-USEEIOMatchingAgent). Salesforce DX project for **Net Zero Cloud** that matches procurement line items (`Scope3PcmtItem`) to **USEEIO-style** emissions factor rows (`PcmtEmssnFctrSetItem`) using **NAICS 2017** logic, keyword pre-filtering, an **LLM** invoked via **Prompt Builder + `ConnectApi.EinsteinLLM`**, and a response cache on `LLM_Response_Cache__c`.

### Architecture Overview

- **LWC**: `useeioMatcher` (single-item UX), `bulkMatchingSummary` + `bulkMatchingSummaryModal` (bulk run / polling), `factorSetItemLookup`, `customDatatable`. UI calls `@AuraEnabled` Apex only — **no LLM callouts from the browser**.
- **Apex layering**:
  - `USEEIOMatchingService` — main matching API (single, bulk start, status, review).
  - `KeywordMatchingService` — deterministic candidate NAICS from spending categories.
  - `LLMService` — Prompt Builder invocation, JSON parse, NAICS validation.
  - `LLMResponseCache` — cache get/save against `LLM_Response_Cache__c`.
  - `BulkMatchingQueueable` → `BulkMatchingBatch` — async kickoff and stateful batch execution (dedupe, cache read, deferred cache write, DML updates).
  - DTOs: `MatchingResult`, `AlternativeMatch`, `BulkMatchingResult`, `BulkMatchingStatus`.
- **LLM binding**: `LLM_Config__mdt` holds the Prompt Builder template API name + Connect invocation app; `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` is called from `LLMService`. Default design uses **no Data Library grounding** — candidates and descriptions come from Apex; cache is checked before any LLM call.
- **Notable design constraints**:
  - `main` is **protected**; PRs require a CODEOWNER review and merge with **squash or rebase only** (linear history).
  - There is intentionally **no `upstream` remote** — do not re-add one or pull from the legacy repo.

### Data Flow

```
LWC → @AuraEnabled (USEEIOMatchingService)
   → KeywordMatchingService (candidates)
   → LLMResponseCache (lookup)
   → LLMService → ConnectApi.EinsteinLLM (Prompt Builder template from LLM_Config__mdt)
   → LLMResponseCache (save) → DML on Scope3PcmtItem / Scope3PcmtSummary

Bulk path: BulkMatchingQueueable → BulkMatchingBatch (dedupe, cached reads, batched LLM calls, deferred cache writes, status updates on Scope3PcmtSummary)
```

### Key Components

1. **`USEEIOMatchingService`** — primary `@AuraEnabled` entry points for LWCs (single-item match, bulk start, status polling, review helpers).
2. **`LLMService`** — encapsulates the Prompt Builder / `ConnectApi.EinsteinLLM` invocation and response parsing.
3. **`LLMResponseCache` + `LLM_Response_Cache__c`** — cache layer keyed by category hash + factor set; gates every LLM call.
4. **`BulkMatchingBatch` + `BulkMatchingQueueable`** — async pipeline that drives batched matching from a `Scope3PcmtSummary`, with status fields tracked on the summary.
5. **`useeioMatcher` / `bulkMatchingSummary` LWCs** — the user surfaces; both call services imperatively and render review queues / progress.
6. **Apex tests** (`*Test.cls`) — bulk + cache + LLM mocking; this project is DML- and callout-heavy, so tests cover both.

### DML Operations

- This project is **DML- and callout-heavy** (cache writes, bulk updates on `Scope3PcmtItem` / `Scope3PcmtSummary`, LLM callouts). Follow `Apex Rules.mdc` (fflib + UnitOfWork) when adding new DML paths, and ensure bulk (200+ records) tests cover them.

---

## 📦 Salesforce Integration

### Objects / metadata used

- **Custom Object**: `LLM_Response_Cache__c` (LLM output cache, keyed by category hash + factor set).
- **Custom Metadata Type**: `LLM_Config__mdt` (Prompt Builder template API name + Connect invocation app name).
- **Net Zero Cloud standard objects**: `Scope3PcmtItem`, `Scope3PcmtSummary`, `PcmtEmssnFctrSet`, `PcmtEmssnFctrSetItem`. Bulk-matching custom fields live under `Scope3PcmtSummary/fields/` (status, counts) and `Scope3PcmtItem/fields/` (match metadata, review status).
- **Secrets / external auth**: none today — LLM access is via `ConnectApi.EinsteinLLM` (Prompt Builder), not via Named Credentials. If a future integration adds an outbound HTTP callout, bind it via External Credential + Named Credential and document the principal in `README.md`.

### Platform features

- Lightning Web Components, Apex (`@AuraEnabled`, `Queueable`, `Database.Batchable`, `ConnectApi.EinsteinLLM`).
- API version **66.0** (`sfdx-project.json`).
- Tooling: `sfdx-lwc-jest`, ESLint, Prettier, Husky.

---

## 🧪 Testing Requirements

### LWC (Jest)

- File location: `__tests__/componentName.test.js`
- Coverage: >85%
- Test observable behavior only
- Do not test internal properties
- Use `createElement` from `lwc` package
- Await rerenders: `await Promise.resolve()`

### Apex

- File location: `force-app/main/default/classes/`
- Coverage: >85%
- Test bulk scenarios (200+ records)
- No `SeeAllData=true`
- Use mocks for dependencies
- Test both success and error paths

---

## 📚 Documentation Standards

**Reference**: [Accelerator README.mdc](./.cursor/rules/Accelerator%20README.mdc)

When updating README.md, ensure:

- OSPO-compliant disclaimer present
- Three installation paths (GitHub Deploy, Workbench, CLI)
- Complete technical architecture section
- Proper badge formatting
- Clear usage instructions
- Mermaid diagrams for complex flows

---

## 🔒 Code Quality & Security

### SF Code Analyzer

- Configuration: `code-analyzer.yml`
- Engines: PMD (Apex), ESLint disabled
- All PRs should pass analyzer checks

### Security Requirements

- All SOQL: `WITH USER_MODE`
- Proper exception handling
- No hardcoded IDs
- Input validation at boundaries
- No XSS, SQL injection, command injection vulnerabilities

---

## 🤝 Cross-Tool Compatibility

### Shared Resources

- ✅ All rules in `.cursor/rules/` apply to both tools
- ✅ `REPOSITORY_SUMMARY.md` is the single source of truth
- ✅ Same coding standards and best practices
- ✅ Same testing requirements

### Tool-Specific Notes

**Cursor**:

- Uses `.cursor/rules/*.mdc` files directly
- Applies rules based on file globs and `alwaysApply` flags

**Claude Code**:

- Reads this `CLAUDE.md` file as entry point
- References `.cursor/rules/` for detailed standards
- Uses markdown formatting for responses (not strict JSON)
- Different tool APIs (Read, Edit, Grep, Bash) but same outcomes

---

## 💡 Quick Reference

### Before Any Task

1. ✅ Read [REPOSITORY_SUMMARY.md](./REPOSITORY_SUMMARY.md)
2. ✅ Review relevant rules from [.cursor/rules/](./.cursor/rules/)
3. ✅ Understand component relationships

### When Writing LWC

- Follow [lwc-best-practices.mdc](./.cursor/rules/lwc-best-practices.mdc)
- Test with [lwc-jest-tests.mdc](./.cursor/rules/lwc-jest-tests.mdc)
- > 85% coverage, test DOM only

### When Writing Apex

- Follow [Apex Rules.mdc](./.cursor/rules/Apex%20Rules.mdc) (if adding DML)
- Follow [apex-best-practices.mdc](./.cursor/rules/apex-best-practices.mdc)
- Use `WITH USER_MODE`, `with sharing`
- > 85% coverage, test bulk scenarios

### When Updating Docs

- Use `/readme-generate` skill for interactive README generation
- Or follow [Accelerator README.mdc](./.cursor/rules/Accelerator%20README.mdc) manually
- Include OSPO disclaimer
- Three installation paths

### When Preparing for Open Source

- Use `/prepare-opensource` skill for OSPO compliance
- Generates LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY
- Scans for internal references
- Adds copyright headers
- Creates compliance checklist

---

## 🎓 Learning Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [LWC Dev Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)
- [fflib-apex-common](https://github.com/apex-enterprise-patterns/fflib-apex-common)
- [Salesforce Product Documentation](https://help.salesforce.com/)

---

**Last Updated**: April 2026  
**Template Type**: Salesforce Project with AI Assistant Integration  
**Compatible Tools**: Cursor IDE, Claude Code
