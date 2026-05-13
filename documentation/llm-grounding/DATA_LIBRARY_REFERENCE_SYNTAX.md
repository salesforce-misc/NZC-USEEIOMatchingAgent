# Data Library Reference Syntax for LLM Prompts
## How to Reference Agentforce Data Library in LLM Prompts

## Overview

Based on Salesforce Agentforce documentation, there are **two main approaches** for referencing Data Library content in LLM prompts, depending on how the data is stored:

1. **Knowledge Grounding (File-Based)** - For PDFs uploaded directly to Data Library
2. **Data Cloud DMOs** - For structured data in Data Cloud

## Approach 1: Knowledge Grounding (Recommended for PDF)

**Use Case:** When you upload the NAICS PDF directly to Agentforce Data Library as a knowledge source.

### Setup Steps:

1. **Upload PDF to Data Library:**
   - Navigate to **Agentforce Studio** or **Data Library**
   - Upload "NAICS Codes 2017_Definition_File.pdf"
   - Wait for indexing to complete (Search Index status = "Complete")

2. **Add as Knowledge Source:**
   - In **Agentforce Studio**, add the PDF as a **Knowledge Source**
   - The document is automatically indexed for semantic search

3. **Reference in Prompt:**

**Important:** With Knowledge Grounding, you **don't explicitly reference the file name** in the prompt. Instead, you instruct the LLM to use the Knowledge Library, and Agentforce automatically retrieves relevant sections via RAG (Retrieval-Augmented Generation).

**Prompt Syntax:**
```
System Prompt:
You are an expert in North American Industry Classification System (NAICS) 2017 codes.
Your task is to analyze spending category descriptions and identify the most appropriate 6-digit NAICS code.

You have access to the NAICS 2017 Definition File in the Knowledge Library.
When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.

User Prompt:
Spending Categories:
Category 1: {SpendingCategory1}
Category 2: {SpendingCategory2}
Category 3: {SpendingCategory3}

Search the Knowledge Library for the NAICS 2017 Definition File to find the most appropriate 6-digit industry code that matches these spending categories.

Return your response in JSON format:
{
  "suggestedNaicsCode": "6-digit code",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Explanation referencing specific sections from the NAICS definition",
  "alternativeNaicsCodes": ["code1", "code2"]
}
```

**How It Works:**
- Agentforce's **Reasoning Engine** automatically:
  - Performs semantic search on the PDF based on spending category keywords
  - Retrieves relevant NAICS definition sections
  - Injects those sections into the LLM context before processing
  - LLM sees the relevant definitions and makes the match

**Key Point:** The system handles retrieval automatically - you just need to instruct the LLM to "search the Knowledge Library" or "use the Knowledge Library."

## Approach 2: Data Cloud DMOs (Alternative)

**Use Case:** If you want to store NAICS data as structured records in Data Cloud instead of a PDF.

### Setup Steps:

1. **Create Data Model Object (DMO) in Data Cloud:**
   - Create `NAICS_Library__dlm` object
   - Map NAICS definitions to DMO fields

2. **Reference in Prompt Builder:**
   - In **Prompt Builder**, click **Add Resource**
   - Select **Data Cloud** as resource type
   - Choose the DMO (e.g., `NAICS_Library__dlm`)

3. **Reference in Prompt:**
```
Use merge field syntax:
{!$DataCloud.NAICS_Library__dlm.Definition__c}
```

**Note:** This approach requires parsing the PDF and loading into Data Cloud, which defeats the purpose of using Data Library for simplicity.

## Recommended Implementation for Our Use Case

### For POC: Use Knowledge Grounding (Approach 1)

**Apex Service Method:**
```apex
public class USEEIOMatchingService {
    
    private static String buildPromptWithKnowledgeLibrary(
        String cat1, String cat2, String cat3, List<String> candidateCodes
    ) {
        String prompt = 'System: You are an expert in NAICS 2017 codes. ';
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library. ';
        prompt += 'When analyzing spending categories, search the Knowledge Library for relevant NAICS definitions.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + (cat1 != null ? cat1 : '') + '\n';
        prompt += 'Category 2: ' + (cat2 != null ? cat2 : '') + '\n';
        prompt += 'Category 3: ' + (cat3 != null ? cat3 : '') + '\n\n';
        
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            prompt += 'Focus your search in the Knowledge Library on these candidate NAICS codes: ';
            prompt += String.join(candidateCodes, ', ') + '\n\n';
        }
        
        prompt += 'Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate ';
        prompt += '6-digit industry code. For each candidate code, retrieve its full definition including:\n';
        prompt += '- Industry description\n';
        prompt += '- Cross-references\n';
        prompt += '- Examples\n';
        prompt += '- What activities are included/excluded\n\n';
        
        prompt += 'Analyze the spending categories against the retrieved definitions and select the best match.\n\n';
        
        prompt += 'Return your response in JSON format:\n';
        prompt += '{\n';
        prompt += '  "suggestedNaicsCode": "6-digit code or null",\n';
        prompt += '  "confidence": "HIGH|MEDIUM|LOW",\n';
        prompt += '  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",\n';
        prompt += '  "alternativeNaicsCodes": ["code1", "code2"],\n';
        prompt += '  "uncertaintyFactors": ["factor1", "factor2"]\n';
        prompt += '}';
        
        return prompt;
    }
}
```

### LLM Open Connector Configuration

**When using LLM Open Connector with Agentforce:**

1. **Enable Knowledge Grounding:**
   - In LLM Open Connector settings, enable **Knowledge Grounding**
   - Select the Data Library/Knowledge Source containing the NAICS PDF
   - Configure grounding parameters (retrieval count, relevance threshold)

2. **Grounding Parameters:**
   - **Top K Retrievals:** Number of relevant sections to retrieve (e.g., 5-10)
   - **Relevance Threshold:** Minimum similarity score (e.g., 0.7)
   - **Max Context Length:** Maximum tokens for retrieved context

3. **Automatic Injection:**
   - When you call the LLM via LLM Open Connector with Knowledge Grounding enabled
   - The system automatically:
     - Searches the Knowledge Library based on your prompt
     - Retrieves relevant sections
     - Injects them into the prompt context
     - Sends to LLM

## Verification Steps

### 1. Verify Data Library Setup
- Check that PDF is uploaded and indexed
- Verify Search Index status is "Complete"
- Confirm document is available in Knowledge Sources

### 2. Test Knowledge Grounding
- Use **Agentforce Simulator** to test a prompt
- View **Response Details** or **Log** to see:
  - What sections were retrieved from the PDF
  - How they were injected into the context
  - The final prompt sent to LLM

### 3. Check Permissions
- Ensure Integration User has read access to Knowledge Library
- Verify Data Library sharing settings
- Check field-level security if using DMOs

## Alternative: Explicit Document Reference

**If the above doesn't work, try explicitly naming the document:**

```
Search the document "NAICS Codes 2017_Definition_File.pdf" in the Knowledge Library 
to find the most appropriate NAICS code for these spending categories.
```

**Or reference by Knowledge Source name:**
```
Use the "NAICS 2017 Definitions" Knowledge Source to find the matching NAICS code.
```

## Troubleshooting

### Issue: LLM not finding relevant definitions
**Solution:**
- Verify PDF is fully indexed (check Search Index status)
- Ensure Knowledge Source is active and accessible
- Check that grounding is enabled in LLM Open Connector
- Review retrieved sections in Simulator logs

### Issue: Too much or too little context retrieved
**Solution:**
- Adjust Top K Retrievals parameter
- Modify relevance threshold
- Refine prompt to be more specific about what to search for

### Issue: Performance concerns
**Solution:**
- Use pre-filtering to narrow candidate codes
- Reference specific NAICS codes in prompt
- Limit retrieval count

## Next Steps

1. **Test in Salesforce Org:**
   - Upload NAICS PDF to Data Library
   - Verify indexing completes
   - Test a simple prompt in Agentforce Simulator
   - Check what context is retrieved

2. **Refine Prompt:**
   - Based on Simulator results, refine prompt instructions
   - Adjust grounding parameters if needed
   - Test with real spending category examples

3. **Implement in Apex:**
   - Use the prompt structure above
   - Call LLM via LLM Open Connector
   - Parse JSON response
   - Handle errors gracefully

---

**Note:** The exact syntax may vary slightly depending on your Salesforce org's Agentforce configuration. It's recommended to test in the Simulator first to verify the correct syntax for your specific setup.
