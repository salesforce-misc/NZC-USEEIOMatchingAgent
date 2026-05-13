# Additional LLM Cost Reduction Strategies

## Overview
Beyond the basic optimizations already implemented, here are additional strategies to reduce LLM API costs for bulk matching operations.

## Current Baseline
- **Cost per call**: ~$0.0225 (1,500 input tokens + 250 output tokens)
- **10,000 items**: ~$225
- **100,000 items**: ~$2,250

## Strategy 1: Batch Processing Multiple Items in Single LLM Call

### Concept
Instead of 1 LLM call per item, process multiple items (5-10) in a single call.

### Implementation
```apex
// Instead of:
for (Scope3PcmtItem item : items) {
    LLMResponse response = LLMService.suggestNaicsCode(...); // 1 call per item
}

// Do this:
List<Scope3PcmtItem> batch = new List<Scope3PcmtItem>(); // 5-10 items
String batchPrompt = buildBatchPrompt(batch); // Combine all items
LLMResponse batchResponse = LLMService.suggestNaicsCodeBatch(batchPrompt); // 1 call for batch
// Parse batch response with multiple NAICS suggestions
```

### Prompt Structure
```
System: You are an expert in NAICS codes. Analyze multiple spending category sets and suggest NAICS codes for each.

User: Analyze these spending category sets:

Set 1:
Category 1: [cat1]
Category 2: [cat2]
Category 3: [cat3]
Candidate codes: [codes1]

Set 2:
Category 1: [cat1]
Category 2: [cat2]
Category 3: [cat3]
Candidate codes: [codes2]

...

Return JSON array:
[
  {"itemId": "id1", "suggestedNaicsCode": "123456", "confidence": "HIGH", ...},
  {"itemId": "id2", "suggestedNaicsCode": "789012", "confidence": "MEDIUM", ...}
]
```

### Cost Impact
- **Current**: 10 items = 10 calls = $0.225
- **Batched**: 10 items = 1 call = ~$0.04 (slightly larger prompt, but shared system prompt)
- **Savings**: ~82% reduction
- **10,000 items**: $225 → ~$40 (save $185)
- **100,000 items**: $2,250 → ~$400 (save $1,850)

### Challenges
- **Token limits**: Batch of 10 items might exceed token limits
- **Error handling**: If one item fails, entire batch fails
- **Parsing complexity**: Need to parse array response correctly
- **Optimal batch size**: Need to test (5-10 items per batch)

### Recommendation
**High Impact**: Implement for bulk processing. Start with batches of 5 items, test and optimize.

---

## Strategy 2: Response Caching for Identical Category Combinations

### Concept
Cache LLM responses for identical spending category combinations. Many items likely have the same categories.

### Implementation
```apex
// Create custom object: LLM_Response_Cache__c
// Fields: Category_Hash__c (Text, unique), Suggested_NAICS__c, Confidence__c, Reasoning__c

public class LLMResponseCache {
    public static LLMResponse getCachedResponse(String cat1, String cat2, String cat3) {
        String hash = generateHash(cat1, cat2, cat3);
        
        List<LLM_Response_Cache__c> cached = [
            SELECT Suggested_NAICS__c, Confidence__c, Reasoning__c
            FROM LLM_Response_Cache__c
            WHERE Category_Hash__c = :hash
            LIMIT 1
        ];
        
        if (!cached.isEmpty()) {
            // Return cached response
            return buildResponseFromCache(cached[0]);
        }
        return null;
    }
    
    public static void saveResponse(String cat1, String cat2, String cat3, LLMResponse response) {
        String hash = generateHash(cat1, cat2, String cat3);
        
        LLM_Response_Cache__c cache = new LLM_Response_Cache__c();
        cache.Category_Hash__c = hash;
        cache.Suggested_NAICS__c = response.suggestedNaicsCode;
        cache.Confidence__c = response.confidence;
        cache.Reasoning__c = response.reasoning;
        
        insert cache;
    }
    
    private static String generateHash(String cat1, String cat2, String cat3) {
        String combined = (cat1 != null ? cat1.toLowerCase().trim() : '') + '|' +
                          (cat2 != null ? cat2.toLowerCase().trim() : '') + '|' +
                          (cat3 != null ? cat3.toLowerCase().trim() : '');
        return EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(combined)));
    }
}
```

### Cost Impact
- **Assumption**: 20-30% of items have identical category combinations
- **10,000 items**: 7,000 unique = $157.50, 3,000 cached = $0 (save $67.50)
- **100,000 items**: 70,000 unique = $1,575, 30,000 cached = $0 (save $675)

### Challenges
- **Storage**: Need custom object to store cache
- **Cache invalidation**: When factor set changes, may need to clear cache
- **Hash collisions**: Very unlikely with SHA-256, but possible

### Recommendation
**Medium Impact**: Implement caching layer. High ROI if category combinations repeat frequently.

---

## Strategy 3: Rule-Based Matching Before LLM

### Concept
Use deterministic rules to match obvious cases before calling LLM. Only use LLM for ambiguous cases.

### Implementation
```apex
public class RuleBasedMatchingService {
    // Map of common category patterns to NAICS codes
    private static final Map<String, String> CATEGORY_PATTERNS = new Map<String, String>{
        'accounting|audit|tax' => '541211', // Accounting Services
        'legal|attorney|lawyer' => '541110', // Offices of Lawyers
        'consulting|advisory' => '541611', // Administrative Management Consulting
        'software|saas|application' => '541511', // Custom Computer Programming
        'office supplies|stationery' => '424120', // Stationery and Office Supplies
        // ... add more patterns
    };
    
    public static String findRuleBasedMatch(String cat1, String cat2, String cat3) {
        String combined = (cat1 + ' ' + cat2 + ' ' + cat3).toLowerCase();
        
        for (String pattern : CATEGORY_PATTERNS.keySet()) {
            if (combined.contains(pattern)) {
                return CATEGORY_PATTERNS.get(pattern);
            }
        }
        
        return null; // No rule-based match found
    }
}
```

### Usage Flow
```apex
// Try rule-based first
String ruleBasedNaics = RuleBasedMatchingService.findRuleBasedMatch(cat1, cat2, cat3);
if (ruleBasedNaics != null) {
    // Verify it exists in factor set
    if (factorExistsInSet(ruleBasedNaics, pcmtEmssnFctrSetId)) {
        return ruleBasedNaics; // Skip LLM call
    }
}
// Only call LLM if no rule-based match
```

### Cost Impact
- **Assumption**: 10-20% of items match rules
- **10,000 items**: 8,000 need LLM = $180, 2,000 rule-based = $0 (save $45)
- **100,000 items**: 80,000 need LLM = $1,800, 20,000 rule-based = $0 (save $450)

### Challenges
- **Maintenance**: Need to maintain pattern dictionary
- **Accuracy**: Rules may be less accurate than LLM
- **Coverage**: Only works for common patterns

### Recommendation
**Medium Impact**: Implement for common patterns. Start with top 20-30 patterns, expand based on data analysis.

---

## Strategy 4: Deduplication - Reuse Matches for Duplicate Items

### Concept
Identify items with identical category combinations and reuse the first item's match.

### Implementation
```apex
// In bulk processing
Map<String, Id> categoryHashToFirstItemId = new Map<String, Id>();
Map<String, MatchingResult> categoryHashToResult = new Map<String, MatchingResult>();

for (Scope3PcmtItem item : items) {
    String hash = generateCategoryHash(item);
    
    if (categoryHashToResult.containsKey(hash)) {
        // Reuse existing match
        MatchingResult cachedResult = categoryHashToResult.get(hash);
        MatchingResult newResult = cachedResult.clone();
        newResult.scope3PcmtItemId = item.Id;
        results.add(newResult);
    } else {
        // First time seeing this combination - call LLM
        MatchingResult result = matchSpendItemToFactorInternal(item, summary);
        categoryHashToResult.put(hash, result);
        results.add(result);
    }
}
```

### Cost Impact
- **Assumption**: 30-40% of items are duplicates
- **10,000 items**: 6,000 unique = $135, 4,000 duplicates = $0 (save $90)
- **100,000 items**: 60,000 unique = $1,350, 40,000 duplicates = $0 (save $900)

### Challenges
- **Memory**: Need to store hash map in memory (fine for batches)
- **Validation**: Need to ensure duplicate items can use same match (same factor set)

### Recommendation
**High Impact**: Implement deduplication in bulk processing. Very effective if items repeat.

---

## Strategy 5: Reduce Candidate Codes (50 → 20-30)

### Concept
Narrow candidate codes from 50 to 20-30 before LLM call. Reduces prompt size.

### Implementation
```apex
// Current: Top 50 candidates
List<String> candidateCodes = KeywordMatchingService.findCandidateNaicsCodes(..., 50);

// Optimized: Top 20 candidates
List<String> candidateCodes = KeywordMatchingService.findCandidateNaicsCodes(..., 20);
```

### Cost Impact
- **Current**: 50 candidates × ~20 tokens = 1,000 tokens
- **Optimized**: 20 candidates × ~20 tokens = 400 tokens
- **Savings**: ~600 tokens per call = $0.006 per call
- **10,000 items**: Save $60
- **100,000 items**: Save $600

### Challenges
- **Accuracy**: Fewer candidates might reduce accuracy
- **Testing**: Need to verify accuracy doesn't degrade

### Recommendation
**Low-Medium Impact**: Test with 30 candidates first. If accuracy maintained, reduce to 20.

---

## Strategy 6: Optimize Prompt Size

### Concept
Reduce prompt tokens by removing redundant text, using abbreviations, shortening instructions.

### Current Prompt (Estimated ~1,500 tokens)
```
System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. Your task is to analyze spending category descriptions from corporate procurement systems and identify the most appropriate 6-digit NAICS industry code.

You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library (USEEIO_Reference). When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.

User: Analyze these spending categories:
Category 1: [category1]
Category 2: [category2]
Category 3: [category3]

Candidate NAICS codes to consider: [candidateCodes]

Here are the descriptions for the candidate codes from the emissions factor database:
- 335929: Other Communication and Energy Wire Manufacturing
- 335931: Current-Carrying Wiring Device Manufacturing
...

CRITICAL: You MUST select a code from the candidate codes list above if any are provided. These candidate codes are guaranteed to exist in the emissions factor database. Do NOT suggest codes that are not in the candidate list.

Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate 6-digit industry code. If candidate codes are provided, you MUST choose from those codes. For each candidate code, retrieve its full definition including:
- Industry description
- Cross-references
- Examples
- What activities are included/excluded

Analyze the spending categories against the retrieved NAICS definitions. Match keywords and concepts from the spending categories to the industry descriptions and examples in the chunks. Select the 6-digit NAICS code that best represents the primary economic activity described by the spending categories.

CRITICAL: You must return ONLY valid JSON with no markdown, no code blocks, no explanations, and no additional text. Return your response as a single JSON object:
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

### Optimized Prompt (Estimated ~800 tokens)
```
System: NAICS 2017 expert. Match spending categories to 6-digit NAICS codes.

User: Categories:
1: [cat1]
2: [cat2]
3: [cat3]

Candidates: [codes]

Descriptions:
- [code1]: [desc1]
- [code2]: [desc2]
...

Rules:
- Must select from candidates if provided
- Return JSON only:
{"suggestedNaicsCode":"code","confidence":"HIGH|MEDIUM|LOW","reasoning":"...","alternativeNaicsCodes":[],"uncertaintyFactors":[]}
```

### Cost Impact
- **Current**: ~1,500 tokens
- **Optimized**: ~800 tokens
- **Savings**: ~700 tokens per call = $0.007 per call
- **10,000 items**: Save $70
- **100,000 items**: Save $700

### Challenges
- **Clarity**: Shorter prompts might reduce LLM understanding
- **Testing**: Need to verify accuracy maintained

### Recommendation
**Medium Impact**: Test optimized prompt. If accuracy maintained, implement.

---

## Strategy 7: Use Cheaper Model for Low-Value Items

### Concept
Use less expensive model (e.g., GPT-3.5) for low-value items, premium model for high-value.

### Implementation
```apex
public static String selectModel(Decimal spendAmount) {
    if (spendAmount > 10000) {
        return 'sfdc_ai__DefaultOpenAIGPT4OmniMini'; // Premium model
    } else {
        return 'sfdc_ai__DefaultGPT35Turbo'; // Cheaper model (if available)
    }
}
```

### Cost Impact
- **Assumption**: 80% of items are low-value
- **Premium model**: $0.0225 per call
- **Cheaper model**: ~$0.005 per call (estimated)
- **10,000 items**: 2,000 premium ($45) + 8,000 cheap ($40) = $85 (save $140)
- **100,000 items**: 20,000 premium ($450) + 80,000 cheap ($400) = $850 (save $1,400)

### Challenges
- **Model availability**: Need to verify cheaper models available in org
- **Accuracy**: Cheaper models may be less accurate
- **Testing**: Need to compare accuracy

### Recommendation
**High Impact**: If cheaper models available and accuracy acceptable, implement tiered model selection.

---

## Strategy 8: Skip LLM for High-Confidence Keyword Matches

### Concept
If keyword matching finds a single, very high-scoring candidate, skip LLM and use that candidate.

### Implementation
```apex
List<String> candidateCodes = KeywordMatchingService.findCandidateNaicsCodes(..., 50);
Map<String, Integer> candidateScores = KeywordMatchingService.getCandidateScores(...);

// If top candidate has score > threshold (e.g., 200), skip LLM
if (candidateScores.get(candidateCodes[0]) > 200 && candidateCodes.size() == 1) {
    // High confidence keyword match - skip LLM
    return candidateCodes[0];
}
```

### Cost Impact
- **Assumption**: 5-10% of items have very high keyword match scores
- **10,000 items**: 9,000 need LLM = $202.50, 1,000 skip = $0 (save $22.50)
- **100,000 items**: 90,000 need LLM = $2,025, 10,000 skip = $0 (save $225)

### Challenges
- **Accuracy**: Keyword matching may be less accurate than LLM
- **Threshold tuning**: Need to find optimal score threshold

### Recommendation
**Low Impact**: Implement with conservative threshold. Only skip LLM for very obvious matches.

---

## Strategy 9: Historical Learning - Learn from Previous Matches

### Concept
Track which category combinations map to which NAICS codes. Use historical data to suggest matches.

### Implementation
```apex
// Custom object: Match_History__c
// Fields: Category_Hash__c, NAICS_Code__c, Confidence__c, Match_Count__c

public static String getHistoricalMatch(String cat1, String cat2, String cat3) {
    String hash = generateHash(cat1, cat2, cat3);
    
    List<Match_History__c> history = [
        SELECT NAICS_Code__c, Confidence__c, Match_Count__c
        FROM Match_History__c
        WHERE Category_Hash__c = :hash
        AND Match_Count__c > 5  // Only use if matched multiple times
        AND Confidence__c >= 0.8  // High confidence
        ORDER BY Match_Count__c DESC
        LIMIT 1
    ];
    
    if (!history.isEmpty()) {
        return history[0].NAICS_Code__c;
    }
    return null;
}
```

### Cost Impact
- **Assumption**: 15-25% of items match historical patterns
- **10,000 items**: 7,500 need LLM = $168.75, 2,500 historical = $0 (save $56.25)
- **100,000 items**: 75,000 need LLM = $1,687.50, 25,000 historical = $0 (save $562.50)

### Challenges
- **Data collection**: Need to build history over time
- **Storage**: Need custom object for history
- **Maintenance**: May need to update/clean history

### Recommendation
**Medium Impact**: Implement as system learns. Start collecting match history, use after sufficient data.

---

## Strategy 10: Combine Strategies - Multi-Tier Approach

### Concept
Combine multiple strategies in a tiered approach: cheapest first, then more expensive.

### Flow
```
1. Check cache (free)
2. Check rule-based matching (free)
3. Check deduplication (free)
4. Check historical matches (free)
5. Check high-confidence keyword match (free)
6. Use cheaper model for low-value items ($0.005)
7. Use premium model for high-value items ($0.0225)
8. Batch process when possible (5 items per call)
```

### Cost Impact
- **10,000 items**:
  - 2,000 cached/rule-based/historical = $0
  - 6,000 low-value (cheaper model, batched) = $6
  - 2,000 high-value (premium model) = $45
  - **Total**: $51 (vs $225 baseline) = **77% reduction**

- **100,000 items**:
  - 20,000 cached/rule-based/historical = $0
  - 60,000 low-value (cheaper model, batched) = $60
  - 20,000 high-value (premium model) = $450
  - **Total**: $510 (vs $2,250 baseline) = **77% reduction**

---

## Implementation Priority

### Phase 1: Quick Wins (High ROI, Low Effort)
1. **Deduplication** - Easy to implement, high impact
2. **Response caching** - Medium effort, high impact if duplicates exist
3. **Skip items without categories** - Already implemented

### Phase 2: Medium Effort (High ROI)
4. **Batch processing** - More complex, but very high impact
5. **Rule-based matching** - Need to build pattern dictionary
6. **Optimize prompt size** - Test and refine

### Phase 3: Advanced (Medium ROI)
7. **Historical learning** - Build over time
8. **Tiered model selection** - If cheaper models available
9. **Reduce candidate codes** - Test accuracy impact

### Phase 4: Optimization (Lower ROI)
10. **Skip high-confidence keyword matches** - Conservative threshold

---

## Expected Combined Savings

If all strategies implemented:
- **Baseline**: $2,250 for 100,000 items
- **Optimized**: ~$500-600 for 100,000 items
- **Savings**: ~$1,650-1,750 (73-78% reduction)

## Next Steps

1. **Implement Phase 1 strategies** (deduplication, caching)
2. **Measure actual duplicate/cache hit rates** in your data
3. **Implement Phase 2** (batch processing, rule-based)
4. **Test and optimize** batch sizes and rules
5. **Implement Phase 3** as system matures
