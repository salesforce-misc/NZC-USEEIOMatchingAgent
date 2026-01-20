# Agentforce Data Library Grounding Approach
## Using Uploaded PDF for LLM Context

## Overview

Instead of creating Custom Metadata Types and parsing the NAICS PDF, we can leverage **Agentforce's Data Library** to upload the NAICS 2017 Definition File PDF directly. The LLM will be able to access and reference this document during matching, providing rich context without manual data extraction.

## Agentforce Data Library

**What it is:**
- Part of Salesforce's Agentforce (AI agent framework)
- Allows users to upload documents (PDFs, Word docs, etc.) to a knowledge base
- Documents are automatically indexed and made available for LLM grounding
- Supports RAG (Retrieval-Augmented Generation) - LLM can retrieve relevant sections from documents

**Benefits:**
- **No data extraction needed** - Upload PDF as-is
- **Automatic indexing** - Agentforce handles document processing
- **Dynamic retrieval** - LLM retrieves relevant sections based on query
- **User-managed** - Users can upload/update documents themselves
- **No code deployment** - Purely declarative setup

## How It Works

### 1. User Uploads PDF
- User uploads "NAICS Codes 2017_Definition_File.pdf" to Agentforce Data Library
- Document is automatically processed and indexed
- Available for LLM grounding in prompts

### 2. LLM Prompt with Data Library Reference
- In the LLM prompt, reference the Data Library document
- LLM automatically retrieves relevant sections from the PDF
- Retrieval is based on the spending category query
- Only relevant NAICS definitions are included in context

### 3. Matching Process
```
Spending Categories → LLM Prompt → Agentforce retrieves relevant NAICS sections from PDF → LLM analyzes → Returns NAICS code
```

## Implementation Approach

### Option 1: Direct Data Library Reference in Prompt

**In the LLM prompt, include:**
```
System Prompt:
You are an expert in North American Industry Classification System (NAICS) 2017 codes.
Your task is to analyze spending category descriptions and identify the most appropriate 6-digit NAICS code.

You have access to the complete NAICS 2017 Definition File in the Data Library.
When analyzing spending categories, reference the relevant NAICS code definitions from this document.

User Prompt:
Spending Categories:
Category 1: {SpendingCategory1}
Category 2: {SpendingCategory2}
Category 3: {SpendingCategory3}

Based on these spending categories, search the NAICS 2017 Definition File in the Data Library 
to find the most appropriate 6-digit industry code.

Return your response in JSON format:
{
  "suggestedNaicsCode": "6-digit code",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Explanation referencing specific NAICS definition sections",
  "alternativeNaicsCodes": ["code1", "code2"]
}
```

**Agentforce automatically:**
- Retrieves relevant sections from the PDF based on spending categories
- Includes those sections in the LLM context
- LLM analyzes with grounded context

### Option 2: Two-Stage with Pre-Filtering + Data Library

**Stage 1: Pre-Filter (Still Needed)**
- Extract keywords from spending categories
- Query `PcmtEmssnFctrSetItem` to get candidate NAICS codes (top 30-50)
- This narrows down which NAICS codes to look up in the PDF

**Stage 2: LLM with Data Library**
- Build prompt with spending categories
- Reference specific NAICS codes to look up in Data Library
- Agentforce retrieves definitions for those codes from PDF
- LLM analyzes with full definitions

**Prompt Example:**
```
Spending Categories:
Category 1: {SpendingCategory1}
Category 2: {SpendingCategory2}
Category 3: {SpendingCategory3}

Candidate NAICS Codes to look up in Data Library:
{List of 30-50 candidate codes}

For each candidate code, retrieve its definition from the NAICS 2017 Definition File 
in the Data Library, including:
- Full industry description
- Cross-references
- Examples
- What's included/excluded

Analyze the spending categories against these definitions and select the best match.
```

## Advantages of Data Library Approach

### 1. **Simplicity**
- No Custom Metadata Type needed
- No PDF parsing required
- No data loading scripts
- User uploads PDF once, done

### 2. **Maintainability**
- Users can update PDF when NAICS definitions change
- No code deployment needed
- Self-service document management

### 3. **Rich Context**
- LLM gets full PDF content (all definitions)
- Agentforce handles retrieval of relevant sections
- Automatic relevance ranking

### 4. **Cost Efficiency**
- Agentforce only retrieves relevant sections (not entire PDF)
- Optimized token usage
- No need to include all 1016 definitions in every call

### 5. **Flexibility**
- Can add additional reference documents
- Multiple PDFs can be in Data Library
- Easy to update or replace documents

## Implementation Details

### Step 1: Set Up Data Library (User Action)

**In Salesforce:**
1. Navigate to Agentforce Data Library
2. Upload "NAICS Codes 2017_Definition_File.pdf"
3. Document is automatically indexed
4. Available for grounding in LLM prompts

### Step 2: Update LLM Service

**Apex Service Method:**
```apex
public class USEEIOMatchingService {
    
    public static MatchingResult matchSpendItemToFactor(Id scope3PcmtItemId) {
        // 1. Query Scope3PcmtItem
        Scope3PcmtItem item = [SELECT SpendingCategory1, SpendingCategory2, SpendingCategory3,
                                       ProcurementSummaryId
                                FROM Scope3PcmtItem 
                                WHERE Id = :scope3PcmtItemId];
        
        // 2. Get PcmtEmssnFctrSetId from parent
        Scope3PcmtSummary summary = [SELECT PcmtEmssnFctrId 
                                     FROM Scope3PcmtSummary 
                                     WHERE Id = :item.ProcurementSummaryId];
        
        // 3. Pre-filter to get candidate NAICS codes (optional but recommended)
        List<String> candidateCodes = findCandidateNaicsCodes(
            item.SpendingCategory1,
            item.SpendingCategory2, 
            item.SpendingCategory3
        );
        
        // 4. Build LLM prompt with Data Library reference
        String prompt = buildPromptWithDataLibrary(
            item.SpendingCategory1,
            item.SpendingCategory2,
            item.SpendingCategory3,
            candidateCodes
        );
        
        // 5. Call LLM via LLM Open Connector
        String llmResponse = LLMService.callLLM(prompt);
        
        // 6. Parse response and find matching factor
        // ... rest of matching logic
    }
    
    private static String buildPromptWithDataLibrary(
        String cat1, String cat2, String cat3, List<String> candidateCodes
    ) {
        String prompt = 'System: You are an expert in NAICS 2017 codes. ';
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Data Library. ';
        prompt += 'Use this document to find the most appropriate NAICS code.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + cat1 + '\n';
        prompt += 'Category 2: ' + cat2 + '\n';
        prompt += 'Category 3: ' + cat3 + '\n\n';
        
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            prompt += 'Focus on these candidate NAICS codes in the Data Library: ';
            prompt += String.join(candidateCodes, ', ') + '\n\n';
        }
        
        prompt += 'Search the NAICS 2017 Definition File in the Data Library to find the best match. ';
        prompt += 'For each candidate code, retrieve its full definition including description, ';
        prompt += 'cross-references, and examples.\n\n';
        
        prompt += 'Return JSON: {"suggestedNaicsCode": "code", "confidence": "HIGH|MEDIUM|LOW", ';
        prompt += '"reasoning": "explanation", "alternativeNaicsCodes": ["code1", "code2"]}';
        
        return prompt;
    }
}
```

### Step 3: LLM Open Connector Configuration

**In Salesforce Setup:**
1. Configure LLM Open Connector
2. Enable **Knowledge Grounding** in connector settings
3. Select the Data Library/Knowledge Source containing the NAICS PDF
4. Configure grounding parameters:
   - **Top K Retrievals:** Number of relevant sections (e.g., 5-10)
   - **Relevance Threshold:** Minimum similarity score (e.g., 0.7)
   - **Max Context Length:** Maximum tokens for retrieved context
5. LLM calls automatically include Knowledge Library context

**Important:** With Knowledge Grounding, you don't need to explicitly reference the file name in the prompt. The system automatically retrieves relevant sections based on your prompt content. Just instruct the LLM to "search the Knowledge Library" or "use the Knowledge Library."

See `DATA_LIBRARY_REFERENCE_SYNTAX.md` for detailed syntax and verification steps.

## Pre-Filtering Strategy (Optional but Recommended)

Even with Data Library, pre-filtering is still beneficial:

**Why:**
- Reduces the search space for Agentforce
- More efficient retrieval (focuses on relevant codes)
- Faster response times
- Lower token usage

**How:**
- Still use keyword matching on `PcmtEmssnFctrSetItem` fields
- Get top 30-50 candidate NAICS codes
- Reference those specific codes in the prompt
- Agentforce retrieves definitions for those codes from PDF

**Alternative:**
- Let Agentforce search entire PDF without pre-filtering
- May be slower but simpler
- Good for POC, optimize later

## Comparison: Data Library vs. Custom Metadata

| Aspect | Data Library | Custom Metadata |
|--------|--------------|-----------------|
| Setup | Upload PDF | Parse PDF, create metadata, load data |
| Maintenance | Update PDF | Update metadata records |
| Code Required | Minimal | More code (parsing, loading) |
| Flexibility | Easy to add docs | Requires deployment |
| Performance | Agentforce optimized | Direct queries |
| User Control | Self-service | Admin/developer only |
| Cost | Included in Agentforce | Storage/query costs |

## Recommended Approach

**For POC:**
1. Use Agentforce Data Library (simplest)
2. Upload NAICS PDF to Data Library
3. Reference in LLM prompt
4. Optional: Add pre-filtering for performance

**For Production:**
- Keep Data Library approach
- Add pre-filtering for efficiency
- Monitor performance and optimize as needed
- Consider caching frequently accessed definitions

## Next Steps

1. **Verify Agentforce Data Library Access**
   - Confirm Data Library is available in the org
   - Check permissions and setup requirements

2. **Test Document Upload**
   - Upload NAICS PDF to Data Library
   - Verify indexing and availability

3. **Test LLM Grounding**
   - Create test prompt with Data Library reference
   - Verify LLM can access document content
   - Test retrieval quality

4. **Implement Matching Service**
   - Update Apex service to use Data Library references
   - Test end-to-end matching flow

---

*This approach leverages Agentforce's built-in capabilities, eliminating the need for custom data structures and manual PDF parsing.*
