# Implementing the Real LLM API Call
## Quick Guide to Connect to Agentforce Models API with Data Library Grounding

## Current Status

✅ **Data Library is indexed** - `USEEIO_Reference` is ready  
✅ **Mock code removed** - All test/mock response code has been removed  
⚠️ **API call needs implementation** - The `callLLMOpenConnector()` method needs the actual API call

## Option 1: Use Prompt Builder Template (Recommended - Easiest)

### Step 1: Create Prompt Template in Prompt Builder

1. In Salesforce, go to **Setup** → Search for **"Prompt Builder"** or **"Prompts"**
2. Click **New Prompt**
3. Configure:
   - **Name:** `NAICS_Matching_Prompt`
   - **Type:** `Flex` (or `Field Generation`)
   - **Model:** Select a standard model (e.g., GPT-4o, Claude 3.5 Sonnet)
4. In the prompt template, add:
   ```
   System: You are an expert in North American Industry Classification System (NAICS) 2017 codes.
   Your task is to analyze spending category descriptions and identify the most appropriate 6-digit NAICS code.
   
   You have access to the NAICS 2017 Definition File in the Knowledge Library (USEEIO_Reference).
   When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.
   
   User: Analyze these spending categories:
   Category 1: {category1}
   Category 2: {category2}
   Category 3: {category3}
   
   {!IF(candidateCodes != null && candidateCodes.size() > 0, 
        'Focus your search on these candidate NAICS codes: ' + candidateCodes, 
        '')}
   
   Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate 6-digit industry code.
   
   Return your response in JSON format:
   {
     "suggestedNaicsCode": "6-digit code or null",
     "confidence": "HIGH|MEDIUM|LOW",
     "reasoning": "Detailed explanation",
     "alternativeNaicsCodes": ["code1", "code2"],
     "uncertaintyFactors": ["factor1", "factor2"]
   }
   ```
5. **Enable Knowledge Grounding:**
   - In prompt settings, enable **"Use Knowledge Grounding"**
   - Select **"Data Library"** as source
   - Select **"USEEIO_Reference"** as your Knowledge Source
6. **Save** the prompt

### Step 2: Update LLMService.cls

Replace the `callLLMOpenConnector()` method with:

```apex
private static String callLLMOpenConnector(String prompt) {
    try {
        // Use Prompt Builder template
        String templateName = 'NAICS_Matching_Prompt';
        
        // Extract variables from prompt (or pass them directly)
        // For now, we'll use the full prompt as-is
        // In production, you might want to parse the prompt and extract variables
        
        // Call via Models API
        // Note: Exact syntax depends on your org version
        // Check: https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html
        
        // Example syntax (verify in your org):
        // aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
        // request.promptTemplate = templateName;
        // request.variables = variables;
        // aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
        // return response.text;
        
        // If the above doesn't work, try:
        // return aiplatform.ModelsAPI.invokeTemplate(templateName, variables);
        
        throw new LLMServiceException('Please implement Models API call. See IMPLEMENT_LLM_API.md for instructions.');
        
    } catch (Exception e) {
        throw new LLMServiceException('Models API call failed: ' + e.getMessage());
    }
}
```

## Option 2: Direct Models API Call

If you prefer not to use Prompt Builder, you can call the Models API directly:

```apex
private static String callLLMOpenConnector(String prompt) {
    try {
        // Direct Models API call
        // Note: Verify exact syntax for your org version
        
        // Create request
        aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
        request.model = 'gpt-4o'; // or getModelName()
        request.prompt = prompt;
        
        // Configure grounding
        request.grounding = new aiplatform.ModelsAPI.Grounding();
        request.grounding.enabled = true;
        request.grounding.source = 'DATA_LIBRARY';
        // request.grounding.knowledgeSourceId = 'USEEIO_Reference'; // Optional
        
        // Set parameters
        request.temperature = 0.2;
        request.maxTokens = 2000;
        
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
```

## Finding the Correct API Syntax

The exact API syntax may vary by org version. To find the correct syntax:

1. **Check Salesforce Documentation:**
   - https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html
   - https://developer.salesforce.com/docs/ai/agentforce/guide/access-models-api-with-apex.html

2. **Check Your Org's API Version:**
   - Your project uses API version 65.0
   - Check if Models API is available in that version

3. **Use Developer Console:**
   - Open Developer Console
   - Try: `aiplatform.ModelsAPI` in the Execute Anonymous window
   - Check what classes/methods are available

4. **Check Prompt Builder:**
   - If Prompt Builder is available, use Option 1 (Template approach)
   - This is often the most reliable method

## Quick Test

Once implemented, test with:

```apex
Id testItemId = '0pdKY000000bmK0YAI'; // Your test item
MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);
System.debug('Result: ' + JSON.serialize(result));
```

## Troubleshooting

### "Invalid type: aiplatform.ModelsAPI"
- The Models API may not be available in your org version
- Try using Prompt Builder templates instead (Option 1)
- Check if Agentforce Models API feature is enabled

### "Knowledge Library not found"
- Verify Data Library `USEEIO_Reference` is indexed
- Check that grounding is enabled in your prompt template
- Ensure the prompt mentions "Knowledge Library" or "Data Library"

### "Empty response"
- Check that the prompt is correctly formatted
- Verify the LLM model is available in your org
- Check API limits/quota

---

**Next Step:** Implement one of the options above, then test in the UI!
