# Quick Start: Connect to Live LLM API
## Your Data Library is Ready - Let's Connect!

## Current Status
✅ Data Library `USEEIO_Reference` is **fully indexed**  
✅ All mock code has been **removed**  
⚠️ Need to implement the **actual Models API call**

## Fastest Path: Use Prompt Builder (5 minutes)

### Step 1: Create Prompt Template

1. Go to **Setup** → Search **"Prompt Builder"**
2. Click **New Prompt**
3. Fill in:
   - **Name:** `NAICS_Matching_Prompt`
   - **Type:** `Flex`
   - **Model:** `GPT-4o` (or any available model)
4. **Prompt Text:**
   ```
   System: You are an expert in NAICS 2017 codes. You have access to the NAICS 2017 Definition File in the Knowledge Library (USEEIO_Reference).
   
   User: Analyze these spending categories:
   Category 1: {category1}
   Category 2: {category2}  
   Category 3: {category3}
   
   {!IF(candidateCodes != null && candidateCodes.size() > 0, 
        'Focus on these candidate NAICS codes: ' + candidateCodes, 
        '')}
   
   Search the Knowledge Library to find the most appropriate 6-digit NAICS code.
   
   Return JSON:
   {
     "suggestedNaicsCode": "6-digit code or null",
     "confidence": "HIGH|MEDIUM|LOW",
     "reasoning": "explanation",
     "alternativeNaicsCodes": ["code1", "code2"],
     "uncertaintyFactors": []
   }
   ```
5. **Enable Knowledge Grounding:**
   - Toggle **"Use Knowledge Grounding"** ON
   - Select **"Data Library"**
   - Select **"USEEIO_Reference"**
6. **Save**

### Step 2: Update LLMService.cls

Replace the `callLLMOpenConnector()` method with this (using your template name):

```apex
private static String callLLMOpenConnector(String prompt) {
    try {
        // Use Prompt Builder template
        String templateName = 'NAICS_Matching_Prompt';
        
        // Parse prompt to extract variables (or pass them directly)
        // For simplicity, we'll pass the full prompt
        // In production, you might parse and extract category1, category2, category3, candidateCodes
        
        // Call Models API with template
        // Note: Verify exact syntax in your org
        aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
        request.promptTemplate = templateName;
        
        // Extract variables from the prompt string
        // This is a simplified approach - you may want to pass variables directly
        Map<String, Object> variables = extractVariablesFromPrompt(prompt);
        request.variables = variables;
        
        // Invoke
        aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
        
        if (response != null && response.text != null) {
            return response.text;
        } else {
            throw new LLMServiceException('Empty response from Models API');
        }
        
    } catch (Exception e) {
        throw new LLMServiceException('Models API call failed: ' + e.getMessage());
    }
}

// Helper to extract variables (simplified - you may want to pass them directly)
private static Map<String, Object> extractVariablesFromPrompt(String prompt) {
    Map<String, Object> vars = new Map<String, Object>();
    // Parse prompt to extract category1, category2, category3, candidateCodes
    // For now, return empty - you'll need to pass these from suggestNaicsCode()
    return vars;
}
```

**Better approach:** Modify `suggestNaicsCode()` to pass variables directly instead of building a prompt string.

## Alternative: Direct API Call

If you prefer direct API calls, check the exact syntax in your org's documentation or Developer Console.

## Test It

Once implemented, refresh your UI and click "Find Emissions Factor" - it should now use the real LLM with Data Library grounding!

---

**Need help?** Check `IMPLEMENT_LLM_API.md` for more detailed options.
