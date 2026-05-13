# LLM Grounding Strategy for NAICS Code Matching
## How the LLM Identifies the Right NAICS Code from Spending Categories

## Overview

The LLM needs to analyze free-text spending category fields and identify the most appropriate 6-digit NAICS 2017 code from a set of 1016 available codes. This requires grounding the LLM with NAICS code definitions so it can make informed matches.

## Challenge

- **1016 NAICS codes** available in PcmtEmssnFctrSetItem records
- **Free-text spending categories** with high variation
- **Token limits** - Cannot include all 1016 definitions in every LLM call
- **Cost optimization** - Need to minimize context size
- **Accuracy** - Must provide relevant context for accurate matching

## Grounding Strategy: Two-Stage Approach

### Stage 1: Keyword-Based Pre-Filtering (Narrow Down Candidates)

**Purpose:** Reduce 1016 codes to a manageable subset (20-50 codes) before LLM analysis

**Approach:**
1. Extract keywords from spending categories
2. Build a keyword-to-NAICS mapping/index
3. Score NAICS codes based on keyword matches
4. Select top N candidates (e.g., top 30-50)

**Implementation:**

#### Option A: Simple Keyword Matching
```apex
// Extract keywords from spending categories
Set<String> keywords = extractKeywords(category1, category2, category3);

// Query all PcmtEmssnFctrSetItem records
List<PcmtEmssnFctrSetItem> allFactors = [SELECT EconomicSectorCode, EconomicSector 
                                          FROM PcmtEmssnFctrSetItem];

// Score each NAICS code based on keyword matches
Map<String, Integer> naicsScores = new Map<String, Integer>();
for (PcmtEmssnFctrSetItem factor : allFactors) {
    Integer score = calculateKeywordMatchScore(keywords, factor.EconomicSector);
    naicsScores.put(factor.EconomicSectorCode, score);
}

// Get top 30-50 candidates
List<String> candidateNaicsCodes = getTopCandidates(naicsScores, 50);
```

**Keyword Extraction:**
- Tokenize spending category text
- Remove stop words (the, a, an, and, or, etc.)
- Normalize (lowercase, remove punctuation)
- Extract meaningful terms (nouns, industry terms)

**Scoring Logic:**
- Exact keyword match: +10 points
- Partial keyword match (contains): +5 points
- Industry-specific terms: +15 points (e.g., "manufacturing", "services", "retail")
- Multiple keyword matches: Cumulative scoring

#### Option B: Enhanced Semantic Pre-Filtering (Future Enhancement)
- Use Salesforce Einstein Search or vector embeddings
- Semantic similarity search
- More sophisticated than keyword matching
- Better for handling synonyms and related terms

### Stage 2: LLM Analysis with Grounded Context

**Purpose:** Use LLM to analyze spending categories with relevant NAICS definitions

**Approach:**
1. Take top N candidates from Stage 1
2. Retrieve NAICS definitions for those candidates
3. Build LLM prompt with spending categories + candidate NAICS definitions
4. LLM analyzes and selects best match

**NAICS Definition Source:**

We need to provide the LLM with NAICS code definitions. Options:

#### Option 1: Use NAICS Knowledge Base (Recommended for POC)
- We have the NAICS 2017 Definition File
- Extract definitions for each 6-digit code
- Store in Custom Metadata Type or Custom Object
- Query definitions for candidate codes

**Structure:**
```
NAICS_Definition__mdt (Custom Metadata Type)
├── Code__c (Text) - 6-digit NAICS code
├── Title__c (Text) - Industry title
├── Description__c (Long Text) - Full industry description
├── Sector__c (Text) - 2-digit sector
├── Subsector__c (Text) - 3-digit subsector
└── Keywords__c (Text) - Key terms for matching
```

#### Option 2: Query from PcmtEmssnFctrSetItem
- Use `EconomicSector` and `EconomicSectorCategory` fields
- These may not have full definitions, but provide context
- Simpler, no additional data storage needed

#### Option 3: External API (Future)
- Call NAICS API for definitions
- More comprehensive but adds external dependency

**For POC, we'll use Option 2 (query from PcmtEmssnFctrSetItem) with Option 1 as enhancement**

## Detailed LLM Prompt Design

### Prompt Structure:

```
System Prompt:
You are an expert in North American Industry Classification System (NAICS) 2017 codes. 
Your task is to analyze spending category descriptions from corporate procurement systems 
and identify the most appropriate 6-digit NAICS industry code.

You will be provided with:
1. Spending category information from a procurement record
2. A list of candidate NAICS codes with their industry descriptions

Analyze the spending categories and select the best matching NAICS code from the candidates.
If none of the candidates are appropriate, indicate that no match was found.

Return your analysis in the specified JSON format.

User Prompt:
Spending Categories:
Category 1: {SpendingCategory1}
Category 2: {SpendingCategory2}
Category 3: {SpendingCategory3}

Candidate NAICS Codes:
{For each candidate code, include:}
- Code: {EconomicSectorCode}
- Industry: {EconomicSector}
- Category: {EconomicSectorCategory}
- Description: {Additional context if available}

Based on this information, identify the most appropriate NAICS 2017 6-digit code.

Return your response in the following JSON format:
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Detailed explanation of why this NAICS code was selected, referencing specific terms from the spending categories",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"],
  "matchedKeywords": ["keyword1", "keyword2"]
}
```

### Context Size Management:

**For 50 candidate codes:**
- Each code: ~100-200 tokens (code + title + description)
- Total context: ~5,000-10,000 tokens
- Spending categories: ~50-100 tokens
- Prompt overhead: ~500 tokens
- **Total: ~6,000-11,000 tokens** (well within most LLM limits)

**Optimization Strategies:**
1. **Truncate descriptions** if too long
2. **Prioritize top candidates** - Include full details for top 10, summary for rest
3. **Use abbreviations** for common terms
4. **Batch processing** - Process multiple items with shared context

## Complete Matching Flow with Grounding

```
1. Extract Spending Categories
   └─> Category1, Category2, Category3

2. Stage 1: Keyword Pre-Filtering
   ├─> Extract keywords from categories
   ├─> Query all PcmtEmssnFctrSetItem records
   ├─> Score NAICS codes based on keyword matches
   └─> Select top 30-50 candidate codes

3. Stage 2: Retrieve NAICS Definitions
   ├─> Query PcmtEmssnFctrSetItem for candidate codes
   ├─> Extract: EconomicSectorCode, EconomicSector, EconomicSectorCategory
   └─> Build context list with code definitions

4. Stage 3: LLM Analysis
   ├─> Build prompt with spending categories + candidate definitions
   ├─> Call LLM with structured prompt
   ├─> Parse JSON response
   └─> Extract suggested NAICS code + confidence + reasoning

5. Stage 4: Find Matching Factors
   ├─> Query PcmtEmssnFctrSetItem where EconomicSectorCode = suggestedCode
   ├─> Filter by PcmtEmssnFctrSet (from Scope3PcmtSummary)
   └─> Return matching factor records

6. Stage 5: Calculate Confidence & Return Results
   ├─> Calculate confidence score
   ├─> Build MatchingResult
   └─> Return to UI
```

## Alternative: Single-Stage LLM Approach (Simpler, Higher Cost)

**Alternative:** Include all 1016 NAICS definitions in prompt

**Pros:**
- Simpler implementation
- No pre-filtering needed
- LLM sees all options

**Cons:**
- Very large context (~200,000+ tokens)
- Higher cost per call
- Slower response times
- May hit token limits

**Not recommended for production, but could work for POC with smaller dataset**

## Implementation Details

### Keyword Matching Service

```apex
public class KeywordMatchingService {
    
    // Common industry keywords mapped to NAICS sectors
    private static final Map<String, Set<String>> INDUSTRY_KEYWORDS = new Map<String, Set<String>> {
        'manufacturing' => new Set<String>{'manufacture', 'factory', 'production', 'assembly'},
        'services' => new Set<String>{'service', 'consulting', 'advisory', 'support'},
        'retail' => new Set<String>{'retail', 'store', 'merchandise', 'sales'},
        // ... more mappings
    };
    
    public static List<String> findCandidateNaicsCodes(
        String category1, 
        String category2, 
        String category3,
        Integer topN
    ) {
        // Extract keywords
        Set<String> keywords = extractKeywords(category1, category2, category3);
        
        // Query all factors
        List<PcmtEmssnFctrSetItem> allFactors = [
            SELECT EconomicSectorCode, EconomicSector, EconomicSectorCategory
            FROM PcmtEmssnFctrSetItem
        ];
        
        // Score each code
        Map<String, Integer> scores = new Map<String, Integer>();
        for (PcmtEmssnFctrSetItem factor : allFactors) {
            Integer score = calculateScore(keywords, factor);
            scores.put(factor.EconomicSectorCode, score);
        }
        
        // Sort and return top N
        List<String> candidates = new List<String>();
        List<Map.Entry<String, Integer>> sortedScores = new List<Map.Entry<String, Integer>>();
        for (String code : scores.keySet()) {
            sortedScores.add(new Map.Entry<String, Integer>(code, scores.get(code)));
        }
        sortedScores.sort(new ScoreComparator());
        
        for (Integer i = 0; i < Math.min(topN, sortedScores.size()); i++) {
            candidates.add(sortedScores[i].getKey());
        }
        
        return candidates;
    }
    
    private static Set<String> extractKeywords(String cat1, String cat2, String cat3) {
        Set<String> keywords = new Set<String>();
        String combined = (cat1 + ' ' + cat2 + ' ' + cat3).toLowerCase();
        
        // Tokenize and remove stop words
        List<String> tokens = combined.split('\\s+');
        Set<String> stopWords = new Set<String>{'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'for'};
        
        for (String token : tokens) {
            token = token.replaceAll('[^a-z0-9]', '');
            if (token.length() > 2 && !stopWords.contains(token)) {
                keywords.add(token);
            }
        }
        
        return keywords;
    }
    
    private static Integer calculateScore(Set<String> keywords, PcmtEmssnFctrSetItem factor) {
        Integer score = 0;
        String sector = (factor.EconomicSector != null ? factor.EconomicSector.toLowerCase() : '');
        String category = (factor.EconomicSectorCategory != null ? factor.EconomicSectorCategory.toLowerCase() : '');
        String combined = sector + ' ' + category;
        
        for (String keyword : keywords) {
            if (combined.contains(keyword)) {
                score += 10; // Base match score
            }
            // Check for partial matches
            if (sector.contains(keyword) || category.contains(keyword)) {
                score += 5;
            }
        }
        
        return score;
    }
}
```

## Performance Considerations

### For POC (Single Item):
- **Stage 1 (Keyword Matching):** < 1 second (query 1016 records, score, sort)
- **Stage 2 (Retrieve Definitions):** < 0.5 seconds (query top 50)
- **Stage 3 (LLM Call):** 2-4 seconds (depends on LLM provider)
- **Total:** ~3-6 seconds per item

### For Production (Bulk):
- **Optimize Stage 1:** Cache keyword index, use Platform Cache
- **Batch LLM Calls:** Process multiple items in single call
- **Parallel Processing:** Use Queueable for async matching
- **Estimated:** 2-3 seconds per item in bulk mode

## Future Enhancements

1. **Vector Embeddings:**
   - Create embeddings for NAICS definitions
   - Use semantic search for better pre-filtering
   - More accurate than keyword matching

2. **Learning from Overrides:**
   - Track user corrections
   - Build mapping patterns
   - Improve keyword matching over time

3. **Custom NAICS Definitions:**
   - Allow customers to add custom descriptions
   - Industry-specific terminology
   - Better matching for specialized sectors

4. **Multi-Language Support:**
   - Handle non-English spending categories
   - Translate to English for LLM
   - Support international NAICS codes

---

*This grounding strategy ensures the LLM has relevant context while maintaining performance and cost efficiency.*
