# Cost Analysis: Grounding vs. Non-Grounding Approach

## Current Approach (No Grounding)

### What We're Doing Now
1. **Pre-filtering**: Use `KeywordMatchingService` to identify 50 candidate NAICS codes
2. **Query Factor Set**: Get `EconomicSector` and `EconomicSectorCategory` descriptions for candidates
3. **Include in Prompt**: Manually add candidate code descriptions to the prompt text
4. **LLM Call**: Send prompt with candidate descriptions, LLM uses its training data

### Current Prompt Structure
```
System: You are an expert in NAICS codes...
User: Analyze these spending categories:
Category 1: [category1]
Category 2: [category2]
Category 3: [category3]

Candidate NAICS codes to consider: [code1, code2, ...]

Here are the descriptions for the candidate codes from the emissions factor database:
- 335929: Other Communication and Energy Wire Manufacturing
- 335931: Current-Carrying Wiring Device Manufacturing
...

CRITICAL: You MUST select a code from the candidate codes list above...
```

### Current Token Usage (Estimated)
- **System prompt**: ~200 tokens
- **User prompt (categories)**: ~50-100 tokens
- **Candidate codes list**: ~50 tokens
- **Candidate descriptions (50 codes × ~20 tokens each)**: ~1,000 tokens
- **Instructions**: ~200 tokens
- **Total input tokens**: ~1,500-1,600 tokens per call
- **Output tokens**: ~200-300 tokens (JSON response)

### Current Cost (Estimated)
- **Input**: 1,500 tokens × $0.01/1K tokens = $0.015
- **Output**: 250 tokens × $0.03/1K tokens = $0.0075
- **Total per call**: ~$0.0225
- **10,000 items**: ~$225
- **100,000 items**: ~$2,250

## With Grounding (Using Retriever)

### What Would Change
1. **Pre-filtering**: Still use `KeywordMatchingService` to identify candidates
2. **Retriever Call**: Use `File_ADL_USEEIO_Referenc_1Cx_vOI485c3618` to fetch relevant chunks from NAICS PDF
3. **Automatic Injection**: Retrieved chunks automatically added to prompt context
4. **Simplified Prompt**: Remove manual candidate descriptions (retriever provides them)

### Grounded Prompt Structure (Estimated)
```
System: You are an expert in NAICS codes...
You have access to the NAICS 2017 Definition File via the retriever.

[RETRIEVER INJECTS ~5 CHUNKS HERE - AUTOMATICALLY]
Chunk 1: "335929 Other Communication and Energy Wire Manufacturing. This U.S. industry comprises establishments primarily engaged in manufacturing insulated wire and cable of nonferrous metals from purchased wire. Cross-References: Establishments primarily engaged in..."
Chunk 2: "335931 Current-Carrying Wiring Device Manufacturing. This U.S. industry comprises establishments primarily engaged in manufacturing current-carrying wiring devices. Illustrative Examples: Bus bars, electrical conductors..."
...

User: Analyze these spending categories:
Category 1: [category1]
Category 2: [category2]
Category 3: [category3]

Candidate NAICS codes to consider: [code1, code2, ...]

Review the retrieved chunks above. Each chunk contains NAICS industry definitions...
CRITICAL: You MUST select a code from the candidate codes list above...
```

### Grounded Token Usage (Estimated)
- **System prompt**: ~200 tokens
- **Retrieved chunks (5 chunks × ~500 tokens each)**: ~2,500 tokens
- **User prompt (categories)**: ~50-100 tokens
- **Candidate codes list**: ~50 tokens
- **Instructions**: ~200 tokens
- **Total input tokens**: ~3,000-3,100 tokens per call
- **Output tokens**: ~200-300 tokens (same JSON response)

### Grounded Cost (Estimated)
- **Input**: 3,000 tokens × $0.01/1K tokens = $0.03
- **Output**: 250 tokens × $0.03/1K tokens = $0.0075
- **Total per call**: ~$0.0375
- **10,000 items**: ~$375
- **100,000 items**: ~$3,750

## Cost Comparison

| Metric | No Grounding | With Grounding | Difference |
|--------|--------------|----------------|------------|
| **Input tokens per call** | ~1,500 | ~3,000 | +100% |
| **Cost per call** | ~$0.0225 | ~$0.0375 | +67% |
| **10,000 items** | ~$225 | ~$375 | +$150 |
| **100,000 items** | ~$2,250 | ~$3,750 | +$1,500 |

## BUT: Potential Cost Savings from Improved Accuracy

### Accuracy Improvements with Grounding

**Current Issues (No Grounding)**:
1. **Invalid NAICS codes**: LLM suggests codes not in factor set (~5-10% of calls)
2. **Low confidence matches**: Many matches below 0.7 threshold (~20-30% of calls)
3. **Manual review needed**: Items requiring human review (~25-35% of items)
4. **Retries**: Some calls fail or need retry (~2-5% of calls)

**With Grounding (Expected)**:
1. **Invalid codes**: Reduced to ~1-2% (LLM has actual definitions)
2. **Low confidence**: Reduced to ~10-15% (more accurate matches)
3. **Manual review**: Reduced to ~12-18% (fewer items need review)
4. **Retries**: Reduced to ~0.5-1% (more reliable responses)

### Cost Savings from Reduced Manual Review

**Assumption**: Manual review costs time, but if we can auto-apply more matches, we save on:
- Re-processing items
- Human review time (not directly LLM cost, but operational cost)

**Example Calculation**:
- **10,000 items, no grounding**:
  - 7,000 auto-applied (70%)
  - 3,000 need review (30%)
  - Cost: $225
  
- **10,000 items, with grounding**:
  - 8,500 auto-applied (85%) - **+1,500 fewer reviews**
  - 1,500 need review (15%)
  - Cost: $375

**Net Effect**: 
- **LLM cost increases**: +$150 for 10,000 items
- **But operational cost decreases**: 1,500 fewer items need manual review
- **If manual review costs $0.10 per item**: Save $150 in operational cost
- **Break-even**: If manual review costs > $0.10/item, grounding saves money overall

## Additional Benefits of Grounding (Beyond Cost)

1. **Better Accuracy**: More correct NAICS code matches
2. **Better Reasoning**: LLM can reference specific sections from NAICS definitions
3. **Reduced Errors**: Fewer invalid codes, fewer retries
4. **Better Confidence Scores**: More accurate confidence assessment
5. **Audit Trail**: Reasoning references actual NAICS definition sections

## Optimization Strategies with Grounding

### 1. Reduce Retrieved Chunks
- **Current estimate**: 5 chunks × 500 tokens = 2,500 tokens
- **Optimize to**: 3 chunks × 400 tokens = 1,200 tokens
- **Savings**: ~1,300 tokens per call = ~$0.013 per call
- **10,000 items**: Save ~$130

### 2. Use Candidate Codes to Guide Retrieval
- **Current**: Retriever searches based on spending categories
- **Optimize**: Retriever searches specifically for candidate NAICS codes
- **Result**: More relevant chunks, potentially fewer chunks needed
- **Savings**: Could reduce to 2-3 chunks instead of 5

### 3. Cache Retrieved Chunks
- **For items with same/similar categories**: Reuse retrieved chunks
- **Challenge**: Each item is unique, but some categories repeat
- **Potential savings**: ~10-20% if we can cache 20% of retrievals

### 4. Batch Processing with Shared Context
- **Process multiple items with similar categories together**
- **Share retrieved chunks across items in batch**
- **Challenge**: Complex to implement, may not save much if items are diverse

## Recommendation

### Short Answer: **Grounding would INCREASE LLM cost per call (~67% increase)**, but could reduce overall operational cost if manual review is expensive.

### Decision Factors:

**Choose Grounding If**:
- Manual review costs > $0.10 per item
- Accuracy is critical (compliance, audit requirements)
- You want better reasoning/audit trail
- You can optimize retriever settings (fewer chunks, better targeting)

**Stick with No Grounding If**:
- Cost is primary concern
- Manual review is cheap/fast
- Current accuracy is acceptable
- You're processing very large volumes (100K+ items)

### Hybrid Approach (Best of Both Worlds)

**Option**: Use grounding selectively:
- **High-value items**: Use grounding (better accuracy worth the cost)
- **Low-value items**: Skip grounding (use current approach)
- **Threshold**: Use grounding if spending amount > $X or confidence needed > Y

**Example**:
- Items with spend > $10,000: Use grounding
- Items with spend < $10,000: No grounding
- **Result**: ~20% of items use grounding, 80% don't
- **Cost**: ~$300 for 10,000 items (vs $375 all grounded, vs $225 none grounded)

## Conclusion

**Grounding increases LLM cost by ~67% per call**, but the improved accuracy could reduce operational costs (manual review) enough to offset the increase, especially if:
1. Manual review is expensive
2. You optimize retriever settings (fewer chunks)
3. You use grounding selectively (high-value items only)

**For bulk processing (10K-100K items)**, the cost difference is significant ($150-$1,500 more), so grounding should be justified by accuracy/operational benefits, not just cost savings.
