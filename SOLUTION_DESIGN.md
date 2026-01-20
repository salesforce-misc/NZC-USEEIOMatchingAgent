# USEEIO Emissions Factor Matching Agent - Solution Design
## Proof of Concept: Single Item Matching

## Overview

An AI-powered matching service that analyzes free-text spending category fields on `Scope3PcmtItem` records to suggest the most appropriate `PcmtEmssnFctrSetItem` (emissions factor) based on NAICS code matching. The solution starts with a single-item proof of concept, then scales to bulk processing.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Interface Layer                           │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │  LWC Component   │  │   Screen Flow    │                     │
│  │  (Interactive)   │  │  (Guided)        │                     │
│  └────────┬─────────┘  └────────┬─────────┘                     │
└───────────┼──────────────────────┼──────────────────────────────┘
            │                      │
            └──────────┬───────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                  Service Layer (Apex)                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         USEEIOMatchingService                            │   │
│  │  - Analyze spending categories                           │   │
│  │  - Call LLM for NAICS code suggestion                    │   │
│  │  - Find matching PcmtEmssnFctrSetItem records            │   │
│  │  - Calculate confidence scores                           │   │
│  │  - Return match results                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│              LLM Integration Layer                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  LLM Open Connector / BYO LLM                             │   │
│  │  - Structured prompt with context                         │   │
│  │  - NAICS code definitions (RAG context)                  │   │
│  │  - JSON schema for structured output                      │   │
│  │  - Returns: NAICS code + confidence + reasoning           │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                    Data Layer                                    │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ Scope3PcmtItem   │  │PcmtEmssnFctrSetItem│                 │
│  │ (Spend Data)     │  │ (Emissions Factors)│                 │
│  └──────────────────┘  └──────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Component 1: Matching Service (Apex)

### Class: `USEEIOMatchingService`

**Purpose:** Core business logic for matching spend records to emissions factors

**Key Methods:**

#### 1. `matchSpendItemToFactor(Id scope3PcmtItemId)`
**Input:** Scope3PcmtItem record ID  
**Output:** `MatchingResult` wrapper class

**Process Flow:**
1. Query `Scope3PcmtItem` record with spending categories and `ProcurementSummaryId`
2. Query `Scope3PcmtSummary` to get `PcmtEmssnFctrId` (required for validation)
3. Extract and normalize spending category text (Category1, 2, 3)
4. **Stage 1:** Keyword-based pre-filtering to narrow down to top 30-50 NAICS candidates
5. **Stage 2:** Call LLM service with spending categories + candidate NAICS definitions
6. **Stage 3:** Query `PcmtEmssnFctrSetItem` records matching suggested NAICS code, filtered by `PcmtEmssnFctrSetId`
7. Calculate confidence scores for each potential match
8. Return top match(es) with confidence scores

#### 2. `analyzeSpendingCategories(String cat1, String cat2, String cat3)`
**Purpose:** Prepare spending category data for LLM analysis

**Logic:**
- Combine categories into a single context string
- Normalize text (trim, handle nulls)
- Return formatted string for LLM prompt

#### 3. `findMatchingFactors(String naicsCode, Id scope3PcmtItemId)`
**Purpose:** Find PcmtEmssnFctrSetItem records by NAICS code, filtered by parent PcmtEmssnFctrSet

**Logic:**
- Query `Scope3PcmtItem` to get `ProcurementSummaryId`
- Query `Scope3PcmtSummary` to get `PcmtEmssnFctrId` (the PcmtEmssnFctrSet)
- Query `PcmtEmssnFctrSetItem` where:
  - `EconomicSectorCode = naicsCode` (exact 6-digit match only)
  - `PcmtEmssnFctrSetId = PcmtEmssnFctrId` (must be child of correct factor set)
- Return list of matching factor records
- **Note:** Only 6-digit NAICS codes exist, so no hierarchical fallback needed

#### 4. `calculateConfidenceScore(String suggestedNaics, List<PcmtEmssnFctrSetItem> matches, String llmConfidence)`
**Purpose:** Calculate overall confidence score for the match

**Factors:**
- LLM confidence level (high/medium/low)
- Exact NAICS match vs. hierarchical fallback
- Number of potential matches found
- Category text clarity/ambiguity

**Returns:** Decimal score (0.0 - 1.0)

#### 5. `applyMatch(Id scope3PcmtItemId, Id pcmtEmssnFctrSetItemId, Decimal confidenceScore)`
**Purpose:** Apply the match to the Scope3PcmtItem record

**Logic:**
- Update `PcmtEmssnFctrSetItemId` field
- Update confidence score field (custom field)
- Log match decision for audit

### Supporting Classes:

#### `MatchingResult` (Wrapper Class)
```apex
public class MatchingResult {
    public Id scope3PcmtItemId;
    public Id recommendedFactorId;
    public String recommendedNaicsCode;
    public String recommendedEconomicSector;
    public Decimal confidenceScore;
    public String reasoning; // LLM reasoning
    public List<AlternativeMatch> alternatives; // Other potential matches
    public String status; // 'MATCHED', 'NO_MATCH', 'REQUIRES_REVIEW'
}
```

#### `AlternativeMatch` (Wrapper Class)
```apex
public class AlternativeMatch {
    public Id factorId;
    public String naicsCode;
    public String economicSector;
    public Decimal confidenceScore;
    public String reasoning;
}
```

## Component 2: LLM Integration

### Approach: LLM Open Connector / BYO LLM

**Integration Pattern:**
- Use Salesforce's LLM Open Connector framework
- Support multiple LLM providers (OpenAI, Anthropic, etc.)
- Structured prompts with RAG context

### LLM Grounding Strategy: Enhanced Two-Stage Approach with NAICS Definitions

**Challenge:** We have 1016 NAICS codes, but can't include all definitions in every LLM call due to token limits and cost. Additionally, the `PcmtEmssnFctrSetItem` fields (`EconomicSector`, `EconomicSectorCategory`) may not contain the full, detailed NAICS definitions needed for accurate matching.

**Solution: Enhanced Two-Stage Pre-Filtering + LLM Analysis with Full NAICS Definitions**

#### Stage 1: Enhanced Semantic Pre-Filtering
**Purpose:** Narrow down 1016 codes to top 30-50 candidates using full NAICS definitions

**Data Source:** Custom Metadata Type `NAICS_Definition__mdt` containing:
- Full industry descriptions from NAICS 2017 Definition File
- Cross-references and exclusions
- Illustrative examples
- Keywords and industry context

**Process:**
1. Extract keywords from spending categories (Category1, 2, 3)
2. Query `NAICS_Definition__mdt` Custom Metadata records (all 1016 codes)
3. Score each NAICS code based on keyword matches in:
   - `Title__c` (industry title) - highest weight
   - `Keywords__c` (curated keywords) - high weight
   - `Description__c` (full description) - medium weight
   - `Illustrative_Examples__c` (concrete examples) - lower weight
4. Select top 30-50 candidate codes with highest scores

**Enhanced Scoring:**
- Title match: +20 points (industry name is most important)
- Keywords field match: +15 points (curated, relevant terms)
- Description match: +10 points (full context)
- Examples match: +8 points (concrete use cases)
- Multiple keyword matches: Cumulative scoring

**Performance:** < 1 second (Custom Metadata queries are fast, in-memory scoring)

#### Stage 2: LLM Analysis with Rich NAICS Context
**Purpose:** Use LLM to analyze spending categories with comprehensive NAICS definitions

**Process:**
1. Take top 30-50 candidate codes from Stage 1
2. Query `NAICS_Definition__mdt` for those codes to get:
   - `Code__c` (6-digit NAICS code)
   - `Title__c` (Industry title)
   - `Description__c` (Full industry description)
   - `Cross_References__c` (Related industries, exclusions)
   - `Illustrative_Examples__c` (Concrete examples)
   - `Full_Definition__c` (Complete definition text)
3. Build LLM prompt with:
   - Spending categories (Category1, 2, 3)
   - **Full NAICS definitions** including descriptions, examples, and cross-references
4. LLM analyzes with rich context and selects best match
5. Returns: NAICS code, confidence, detailed reasoning, alternatives

**Context Size:**
- 50 candidate codes × ~400 tokens each (full definitions) = ~20,000 tokens
- Spending categories: ~100 tokens
- Prompt overhead: ~500 tokens
- **Total: ~20,500 tokens** (within most LLM limits, optimized if needed)

**Why This Works Better:**
- LLM sees **complete industry definitions**, not just abbreviated titles
- Includes **cross-references** to help understand industry boundaries
- **Examples** provide concrete use cases for matching
- **Full descriptions** explain what's included/excluded
- More accurate matching with richer context
- Still efficient (only top 30-50 candidates, not all 1016)

**Benefits Over Simple Keyword Matching:**
- Better accuracy: Full definitions vs. abbreviated fields
- Handles edge cases: Cross-references clarify boundaries
- More context: Examples and descriptions provide nuance
- Maintainable: Custom Metadata can be updated with new definitions

See `ENHANCED_LLM_GROUNDING.md` for detailed implementation and data extraction strategy.

### Prompt Design:

#### System Prompt:
```
You are an expert in North American Industry Classification System (NAICS) codes and environmental emissions factors. 
Your task is to analyze spending category descriptions and identify the most appropriate NAICS 2017 industry code.

You will be provided with spending category information from a corporate procurement system. 
Analyze the text and determine the primary industry/sector this purchase belongs to.

Return your analysis in the specified JSON format.
```

#### User Prompt Template:
```
Analyze the following spending categories from a corporate procurement record:

Spending Category 1: {Category1}
Spending Category 2: {Category2}
Spending Category 3: {Category3}

Based on this information, identify the most appropriate NAICS 2017 6-digit industry code.

Available NAICS codes and their descriptions:
{NAICS_CONTEXT}  // RAG: Top 20-50 most relevant NAICS code definitions

Return your response in the following JSON format:
{
  "suggestedNaicsCode": "6-digit code",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Explanation of why this NAICS code was selected",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

### RAG Context Strategy:

**For POC (Single Item):**
- Include all 1016 NAICS code definitions in context
- Or use semantic search to find top 20-50 most relevant codes based on category text
- Include NAICS hierarchy information (sector, subsector, industry group)

**For Production (Bulk):**
- Cache NAICS definitions in Platform Cache
- Use semantic search/vector search to find relevant codes
- Optimize context size for cost and performance

### LLM Service Class: `LLMService`

**Methods:**
- `suggestNaicsCode(String categoryText, List<NaicsDefinition> context)` - Main LLM call
- `buildPrompt(String categoryText, List<NaicsDefinition> context)` - Construct prompt
- `parseLLMResponse(String jsonResponse)` - Parse and validate JSON response
- `validateNaicsCode(String code)` - Validate code format and existence

### Error Handling:
- Retry logic for transient failures
- Fallback to rule-based matching if LLM fails
- Graceful degradation with user notification

## Component 3: User Experience

### Phase 1: Proof of Concept (Single Item)

#### Lightning Web Component (POC Implementation)

**Component:** `useeioMatcher`

**Deployment:** Embedded on `Scope3PcmtItem` record page

**Features:**
1. **Record Context**
   - Automatically receives `recordId` from page context (no selection needed)
   - Uses `@api recordId` to get current Scope3PcmtItem record

2. **Spending Category Display**
   - Show Category 1, 2, 3 fields
   - Display in read-only format

3. **Match Button**
   - "Find Emissions Factor" button
   - Triggers matching service
   - Shows loading spinner

4. **Results Display**
   - **Recommended Match:**
     - NAICS code and description
     - Economic sector name
     - Emissions factor value
     - Confidence score (visual indicator: High/Medium/Low)
     - LLM reasoning/explanation
   
   - **Alternative Matches:**
     - Show 2-3 alternative options
     - Allow user to select alternative
   
   - **Actions:**
     - "Apply Match" button (updates record)
     - "Try Again" button (re-run matching)
     - "Manual Search" button (search factors by NAICS)

5. **Confidence Visualization**
   - Progress bar or badge showing confidence level
   - Color coding: Green (High), Yellow (Medium), Red (Low)
   - Tooltip explaining confidence factors

6. **Audit Information**
   - Show when match was made
   - Show who made the match (AI vs. user)
   - Show match history

#### Option B: Screen Flow (Alternative for POC)

**Flow:** `Match_Spend_Item_to_Factor`

**Steps:**
1. **Get Record** - Select Scope3PcmtItem record
2. **Display Categories** - Show spending categories
3. **Match Action** - Call Apex action to find match
4. **Display Results** - Show recommended match with confidence
5. **User Decision** - Accept, Reject, or Search Manually
6. **Apply Match** - Update record if accepted
7. **Confirmation** - Show success message

**Advantages:**
- Declarative, easier to modify
- Built-in error handling
- Native Salesforce UI

### Phase 2: Bulk Processing (Future)

**Component:** `useeioBulkMatcher`

**Features:**
1. **Record Selection**
   - List view of Scope3PcmtItem records
   - Filter by unmatched items
   - Select all or specific records

2. **Bulk Match Button**
   - "Match All Selected" button
   - Shows progress bar
   - Processes in batches (Queueable/Batchable)

3. **Results Summary**
   - Total records processed
   - Matched count with confidence breakdown
   - Unmatched count
   - Requires review count

4. **Review Interface**
   - Filter by confidence level
   - Bulk approve high-confidence matches
   - Review low-confidence matches individually
   - Override matches

5. **Bulk Actions**
   - Apply all high-confidence matches
   - Export unmatched items
   - Retry failed matches

## Data Model Extensions

### Custom Field on Scope3PcmtItem:

**Field:** `Match_Confidence_Score__c`
- **Type:** Number (3,2) - Decimal 0.00 to 1.00
- **Label:** Match Confidence Score
- **Description:** AI-generated confidence score for the emissions factor match
- **Help Text:** 0.00-0.50 = Low, 0.51-0.75 = Medium, 0.76-1.00 = High

**Field:** `Match_Reasoning__c`
- **Type:** Long Text Area (32768 characters)
- **Label:** Match Reasoning
- **Description:** Explanation of why this emissions factor was selected (from LLM)

**Field:** `Match_Source__c`
- **Type:** Picklist
- **Values:** 
  - AI Suggested
  - User Override
  - Manual Selection
- **Label:** Match Source
- **Description:** How the match was determined
- **Default:** AI Suggested

## Matching Logic Flow (Detailed)

### Step 1: Extract Spending Categories
```
Input: Scope3PcmtItem record
Extract: SpendingCategory1, SpendingCategory2, SpendingCategory3
Combine: "Category1: {cat1}\nCategory2: {cat2}\nCategory3: {cat3}"
Normalize: Trim whitespace, handle nulls, remove empty categories
```

### Step 2: LLM Analysis
```
Input: Combined category text
Context: NAICS code definitions (RAG)
LLM Call: Suggest NAICS code with confidence and reasoning
Output: {
  suggestedNaicsCode: "541211" (example),
  confidence: "HIGH",
  reasoning: "The spending categories indicate accounting services...",
  alternativeNaicsCodes: ["541219", "541213"]
}
```

### Step 3: Find Matching Factors
```
Input: Suggested NAICS code (e.g., "541211"), Scope3PcmtItemId
Query Scope3PcmtItem to get ProcurementSummaryId
Query Scope3PcmtSummary to get PcmtEmssnFctrId

Query: SELECT Id, EconomicSectorCode, EconomicSector, TotScpe3EmssnPerMillionSpent 
       FROM PcmtEmssnFctrSetItem 
       WHERE EconomicSectorCode = '541211'
       AND PcmtEmssnFctrSetId = :pcmtEmssnFctrId

Note: Only 6-digit NAICS codes exist in EconomicSectorCode field, so no hierarchical fallback
```

### Step 4: Calculate Confidence Score
```
Factors:
- LLM Confidence: HIGH = 0.9, MEDIUM = 0.6, LOW = 0.3
- Match Type: Exact 6-digit match = 1.0 (always, since only 6-digit codes exist)
- Number of Matches: Single match = 1.0, Multiple = 0.9, None = 0.0
- Factor Set Validation: Match found in correct factor set = 1.0, Not found = 0.0

Formula:
confidenceScore = (llmConfidence * 0.6) + (matchCount * 0.2) + (factorSetMatch * 0.2)

Note: Since match type is always 1.0 (exact 6-digit), we weight LLM confidence higher
```

### Step 5: Return Results
```
Return MatchingResult with:
- Recommended factor ID
- Confidence score
- Reasoning
- Alternative matches
- Status (MATCHED, NO_MATCH, REQUIRES_REVIEW)
```

## Error Handling & Edge Cases

### Edge Cases:

1. **No Spending Categories:**
   - Return status: NO_MATCH
   - Suggest manual selection
   - Confidence: 0.0

2. **Ambiguous Categories:**
   - LLM returns LOW confidence
   - Return multiple alternatives
   - Flag for manual review

3. **No NAICS Match Found:**
   - Try hierarchical fallback
   - If still no match, return NO_MATCH
   - Suggest manual search

4. **Multiple Exact Matches:**
   - Return all matches as alternatives
   - Use additional criteria (if available) to rank
   - Flag for user selection

5. **LLM Failure:**
   - Fallback to keyword-based matching
   - Use NAICS code lookup table
   - Notify user of fallback mode

## Performance Considerations

### For POC (Single Item):
- Response time target: < 5 seconds
- LLM call: ~2-3 seconds
- Database queries: < 1 second
- UI rendering: < 1 second

### For Production (Bulk):
- Batch processing: Queueable or Batchable Apex
- Process 200 records per batch
- Async processing with progress tracking
- Estimated time: ~1-2 seconds per record

## Security & Governance

1. **Field-Level Security:**
   - Users need read access to Scope3PcmtItem
   - Users need read access to PcmtEmssnFctrSetItem
   - Users need edit access to Scope3PcmtItem (to apply matches)

2. **Sharing Rules:**
   - Respect existing sharing rules
   - No cross-object sharing required

3. **Audit Trail:**
   - Track who made matches
   - Track when matches were made
   - Track confidence scores
   - Track overrides

## Testing Strategy

### Unit Tests:
- Test matching service with various category inputs
- Test LLM response parsing
- Test confidence score calculation
- Test hierarchical NAICS matching
- Test error handling

### Integration Tests:
- Test end-to-end matching flow
- Test with real Scope3PcmtItem records
- Test with various category formats
- Test LLM integration (with mocked responses)

### User Acceptance:
- Test with real customer data samples
- Validate match accuracy
- Test user experience
- Gather feedback for improvements

## Next Steps (After POC)

1. **Bulk Processing:**
   - Implement Queueable/Batchable processing
   - Add progress tracking
   - Add bulk review interface

2. **Enhanced Matching:**
   - Consider SupplierId and ProductId
   - Use Scope3GhgCategory for validation
   - Implement learning from user overrides

3. **Performance Optimization:**
   - Cache NAICS definitions
   - Optimize LLM context size
   - Implement batch LLM calls

4. **Advanced Features:**
   - Historical match patterns
   - Auto-approval for high-confidence matches
   - Match quality metrics dashboard

---

*This design provides a solid foundation for the proof of concept, with clear paths for scaling to bulk processing.*
