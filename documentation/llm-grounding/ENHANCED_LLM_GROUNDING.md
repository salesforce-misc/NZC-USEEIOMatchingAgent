# Enhanced LLM Grounding Strategy
## Using NAICS 2017 Definition File for Richer Context

## Overview

Instead of relying solely on keyword matching against `PcmtEmssnFctrSetItem` fields, we'll use the comprehensive NAICS 2017 Definition File to provide the LLM with detailed industry descriptions, cross-references, and examples. This will significantly improve matching accuracy.

## The Problem with Current Approach

**Current Limitation:**
- Only using `EconomicSector` and `EconomicSectorCategory` fields from `PcmtEmssnFctrSetItem`
- These fields may be abbreviated or lack detailed context
- Missing industry descriptions, cross-references, and examples from the official NAICS definitions

**Solution:**
- Use the full NAICS 2017 Definition File content
- Each NAICS code has detailed descriptions including:
  - Industry definition and scope
  - What's included/excluded
  - Cross-references to related codes
  - Illustrative examples
  - Industry group context

## Enhanced Grounding Strategy

### Option 1: Custom Metadata Type (Recommended for POC)

**Structure:**
Create a Custom Metadata Type to store NAICS definitions:

```
NAICS_Definition__mdt (Custom Metadata Type)
├── Code__c (Text, 6) - 6-digit NAICS code (External ID)
├── Title__c (Text, 255) - Industry title
├── Description__c (Long Text Area, 32768) - Full industry description
├── Sector__c (Text, 2) - 2-digit sector code
├── Subsector__c (Text, 3) - 3-digit subsector code
├── Industry_Group__c (Text, 4) - 4-digit industry group code
├── Industry__c (Text, 5) - 5-digit industry code
├── Cross_References__c (Long Text Area) - Cross-reference information
├── Illustrative_Examples__c (Long Text Area) - Examples of activities
├── Keywords__c (Text, 1000) - Extracted keywords for search
└── Full_Definition__c (Long Text Area) - Complete definition text
```

**Advantages:**
- Deployable with code
- Queryable via SOQL
- No additional storage objects needed
- Can be versioned
- Fast access (indexed by Code__c)

**Data Loading:**
- Parse the NAICS 2017 Definition File PDF
- Extract definitions for each 6-digit code
- Create Custom Metadata records
- Deploy to org

### Option 2: Custom Object (Alternative)

**Structure:**
```
NAICS_Definition__c (Custom Object)
├── Code__c (Text, 6, External ID) - 6-digit NAICS code
├── Title__c (Text, 255) - Industry title
├── Description__c (Long Text Area) - Full description
├── ... (same fields as Custom Metadata)
└── Full_Definition_Text__c (Long Text Area) - Complete definition
```

**Advantages:**
- Can be updated without deployment
- Supports data import tools
- Can be bulk loaded via Data Loader

**Disadvantages:**
- Requires storage space
- Slightly slower queries than Custom Metadata

### Option 3: External Data Source (Future)

- Store in external system
- Access via API
- More flexible but adds complexity

**For POC, we'll use Custom Metadata Type (Option 1)**

## Enhanced Matching Flow

### Stage 1: Semantic Pre-Filtering (Instead of Simple Keyword Matching)

**Approach:** Use NAICS definitions for better pre-filtering

**Process:**
1. Extract keywords from spending categories
2. Query `NAICS_Definition__mdt` records
3. Score each NAICS code based on:
   - Keyword matches in `Title__c`
   - Keyword matches in `Description__c`
   - Keyword matches in `Keywords__c`
   - Keyword matches in `Illustrative_Examples__c`
   - Semantic similarity (if using embeddings)
4. Select top 30-50 candidates

**Enhanced Scoring:**
```apex
Integer score = 0;

// Title match (highest weight)
if (title.contains(keyword)) score += 20;

// Description match
if (description.contains(keyword)) score += 10;

// Keywords field match
if (keywords.contains(keyword)) score += 15;

// Examples match
if (examples.contains(keyword)) score += 8;

// Multiple keyword matches = cumulative
```

### Stage 2: LLM Analysis with Rich NAICS Context

**Enhanced Prompt with Full Definitions:**

```
System Prompt:
You are an expert in North American Industry Classification System (NAICS) 2017 codes. 
Your task is to analyze spending category descriptions from corporate procurement systems 
and identify the most appropriate 6-digit NAICS industry code.

You will be provided with:
1. Spending category information from a procurement record
2. A list of candidate NAICS codes with their COMPLETE official definitions, including:
   - Industry title and description
   - What activities are included/excluded
   - Cross-references to related industries
   - Illustrative examples

Analyze the spending categories carefully and select the best matching NAICS code from the candidates.
Consider the full context of what each industry encompasses, not just keyword matches.

Return your analysis in the specified JSON format.

User Prompt:
Spending Categories:
Category 1: {SpendingCategory1}
Category 2: {SpendingCategory2}
Category 3: {SpendingCategory3}

Candidate NAICS Codes with Full Definitions:

[For each of the top 30-50 candidates:]

NAICS Code: {Code__c}
Title: {Title__c}
Description: {Description__c}
Cross-References: {Cross_References__c}
Examples: {Illustrative_Examples__c}
Full Definition: {Full_Definition__c}

---

Based on this comprehensive information, identify the most appropriate NAICS 2017 6-digit code.

Return your response in the following JSON format:
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Detailed explanation referencing specific aspects of the NAICS definition that match the spending categories",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"],
  "matchedDefinitionElements": ["title", "description", "examples"]
}
```

## Implementation Plan

### Step 1: Parse NAICS Definition File

**Extract Data from PDF:**
- Parse the NAICS Codes 2017 Definition File PDF
- For each 6-digit code, extract:
  - Code
  - Title
  - Full description
  - Cross-references
  - Examples
  - Hierarchy (sector, subsector, etc.)

**Parsing Strategy:**
- Use PDF parsing library or tool
- Extract structured data
- Map to Custom Metadata fields

### Step 2: Create Custom Metadata Type

**Metadata Definition:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>NAICS Definition</label>
    <pluralLabel>NAICS Definitions</pluralLabel>
    <visibility>Public</visibility>
    <description>NAICS 2017 industry code definitions for LLM grounding</description>
    <fields>
        <fullName>Code__c</fullName>
        <label>NAICS Code</label>
        <type>Text</type>
        <length>6</length>
        <required>true</required>
        <unique>true</unique>
        <externalId>true</externalId>
        <description>6-digit NAICS 2017 code</description>
    </fields>
    <!-- Additional fields... -->
</CustomObject>
```

### Step 3: Load Data

**Data Loading Options:**

**Option A: Manual CSV Import**
- Export parsed data to CSV
- Use Custom Metadata Type import tool
- Or use SFDX CLI to deploy metadata

**Option B: Apex Script**
- Create Apex script to parse and insert
- Run in Developer Console or Anonymous Apex
- Useful for one-time data load

**Option C: External Tool**
- Use data migration tool
- Import via Metadata API

### Step 4: Update Matching Service

**Enhanced Service Methods:**

```apex
public class USEEIOMatchingService {
    
    // Enhanced pre-filtering using NAICS definitions
    public static List<String> findCandidateNaicsCodes(
        String category1, 
        String category2, 
        String category3,
        Integer topN
    ) {
        // Extract keywords
        Set<String> keywords = extractKeywords(category1, category2, category3);
        
        // Query NAICS definitions (Custom Metadata)
        List<NAICS_Definition__mdt> allDefinitions = [
            SELECT Code__c, Title__c, Description__c, Keywords__c, 
                   Illustrative_Examples__c, Cross_References__c
            FROM NAICS_Definition__mdt
        ];
        
        // Score each definition
        Map<String, Integer> scores = new Map<String, Integer>();
        for (NAICS_Definition__mdt def : allDefinitions) {
            Integer score = calculateEnhancedScore(keywords, def);
            scores.put(def.Code__c, score);
        }
        
        // Return top N
        return getTopCandidates(scores, topN);
    }
    
    private static Integer calculateEnhancedScore(
        Set<String> keywords, 
        NAICS_Definition__mdt definition
    ) {
        Integer score = 0;
        String title = (definition.Title__c != null ? definition.Title__c.toLowerCase() : '');
        String description = (definition.Description__c != null ? definition.Description__c.toLowerCase() : '');
        String keywordsField = (definition.Keywords__c != null ? definition.Keywords__c.toLowerCase() : '');
        String examples = (definition.Illustrative_Examples__c != null ? definition.Illustrative_Examples__c.toLowerCase() : '');
        
        for (String keyword : keywords) {
            // Title match (highest weight - industry name)
            if (title.contains(keyword)) {
                score += 20;
            }
            
            // Keywords field match (curated keywords)
            if (keywordsField.contains(keyword)) {
                score += 15;
            }
            
            // Description match (full context)
            if (description.contains(keyword)) {
                score += 10;
            }
            
            // Examples match (concrete use cases)
            if (examples.contains(keyword)) {
                score += 8;
            }
        }
        
        return score;
    }
    
    // Enhanced LLM context building
    public static String buildLLMPrompt(
        String category1,
        String category2, 
        String category3,
        List<String> candidateCodes
    ) {
        // Query full definitions for candidates
        List<NAICS_Definition__mdt> definitions = [
            SELECT Code__c, Title__c, Description__c, Cross_References__c,
                   Illustrative_Examples__c, Full_Definition__c
            FROM NAICS_Definition__mdt
            WHERE Code__c IN :candidateCodes
            ORDER BY Code__c
        ];
        
        // Build prompt with full context
        String prompt = 'Spending Categories:\n';
        prompt += 'Category 1: ' + category1 + '\n';
        prompt += 'Category 2: ' + category2 + '\n';
        prompt += 'Category 3: ' + category3 + '\n\n';
        prompt += 'Candidate NAICS Codes with Full Definitions:\n\n';
        
        for (NAICS_Definition__mdt def : definitions) {
            prompt += 'NAICS Code: ' + def.Code__c + '\n';
            prompt += 'Title: ' + def.Title__c + '\n';
            if (def.Description__c != null) {
                prompt += 'Description: ' + def.Description__c + '\n';
            }
            if (def.Illustrative_Examples__c != null) {
                prompt += 'Examples: ' + def.Illustrative_Examples__c + '\n';
            }
            if (def.Cross_References__c != null) {
                prompt += 'Cross-References: ' + def.Cross_References__c + '\n';
            }
            prompt += '\n---\n\n';
        }
        
        return prompt;
    }
}
```

## Benefits of Enhanced Approach

### 1. **Richer Context**
- LLM sees full industry definitions, not just abbreviated titles
- Includes what's included/excluded
- Cross-references help LLM understand relationships
- Examples provide concrete use cases

### 2. **Better Accuracy**
- More information = better matching decisions
- LLM can reason about industry scope
- Reduces false positives from keyword-only matching

### 3. **Handles Edge Cases**
- Cross-references help with ambiguous categories
- Examples clarify industry boundaries
- Full definitions explain nuances

### 4. **Maintainable**
- Custom Metadata can be updated
- Version control for definitions
- Easy to add new codes or update descriptions

## Data Extraction from PDF

### Parsing Strategy

**From the NAICS 2017 Definition File, extract:**

For each 6-digit code (e.g., 111110 - Soybean Farming):

1. **Code:** 111110
2. **Title:** "Soybean Farming"
3. **Description:** Full industry description including:
   - What the industry comprises
   - Primary activities
   - What's included/excluded
4. **Cross-References:** Related industries and exclusions
5. **Examples:** Illustrative examples of activities
6. **Hierarchy:** Sector (11), Subsector (111), Industry Group (1111), Industry (11111)

### Example Extraction

```
Code: 111110
Title: Soybean Farming
Description: This industry comprises establishments primarily engaged in growing soybeans and/or producing soybean seeds.
Cross-References: 
- Establishments engaged in growing soybeans in combination with grain(s) with the soybeans or grain(s) not accounting for one-half of the establishment's agricultural production (value of crops for market) are classified in U.S. Industry 111191, Oilseed and Grain Combination Farming.
Examples: Soybean farming, Soybean seed production
Keywords: soybean, farming, agriculture, crop, seed production
```

## Context Size Management

**For 50 candidate codes with full definitions:**
- Each definition: ~300-500 tokens (code + title + description + examples + cross-refs)
- 50 definitions: ~15,000-25,000 tokens
- Spending categories: ~100 tokens
- Prompt overhead: ~500 tokens
- **Total: ~16,000-26,000 tokens**

**Optimization Strategies:**
1. **Truncate if needed:** Limit description length for very long definitions
2. **Prioritize top candidates:** Full details for top 10, summary for rest
3. **Smart truncation:** Keep most relevant parts (title, key description, examples)

## Migration Path

### Phase 1: POC with Custom Metadata
- Create Custom Metadata Type
- Load subset of NAICS definitions (e.g., top 200 most common)
- Test matching accuracy

### Phase 2: Full Implementation
- Load all 1016 NAICS definitions
- Optimize context size
- Monitor performance

### Phase 3: Enhancement
- Add semantic search/embeddings
- Learn from user overrides
- Refine definitions based on feedback

---

*This enhanced approach provides the LLM with comprehensive NAICS definitions, significantly improving matching accuracy compared to keyword-only approaches.*
