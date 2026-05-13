# LLM Integration Setup Guide (Simplified)
## Using Agentforce Native Models with Data Library Grounding

## Overview

You're absolutely right! You **don't need to configure a custom LLM Open Connector** if you use Agentforce's standard managed models (GPT-4, Claude, etc.). This guide shows the simpler approach using Agentforce's native Models API with Data Library grounding.

## Prerequisites

- ✅ Salesforce org with **Agentforce** enabled
- ✅ The **NAICS Codes 2017_Definition_File.pdf** ready to upload
- ✅ System Administrator or appropriate permissions
- ✅ **No external API keys needed** (uses Salesforce's managed models)

## Step 1: Upload NAICS PDF to Agentforce Data Library

### 1.1 Navigate to Agentforce Data Library

1. In Salesforce, go to **Setup** (gear icon)
2. In Quick Find, search for **"Agentforce Studio"** or **"Data Library"**
3. Click on **Agentforce Studio** or **Data Library**

**Alternative Path:**
- Navigate to **App Launcher** → Search for **"Agentforce"** → Open **Agentforce Studio**

### 1.2 Upload the PDF

1. In Agentforce Studio, navigate to **Data Library** or **Knowledge Sources**
2. Click **Upload Document** or **Add Knowledge Source**
3. Select **"NAICS Codes 2017_Definition_File.pdf"**
4. Wait for upload to complete
5. **Important:** Wait for indexing to complete (Status should show "Indexed" or "Complete")

### 1.3 Verify Indexing

1. Check the document status - it should show **"Indexed"** or **"Search Index: Complete"**
2. If status is "Indexing" or "Pending", wait a few minutes and refresh
3. Note the **Knowledge Source Name** or **Document ID** (you may need this)

**Troubleshooting:**
- If indexing fails, try re-uploading the PDF
- Ensure the PDF is not password-protected
- Check file size limits (typically 50MB max)

## Step 2: Use Agentforce Models API in Apex

### 2.1 Update LLMService.cls

Replace the `callLLMOpenConnector()` method to use Agentforce's native Models API:

```apex
/**
 * @description Call LLM via Agentforce Models API with Data Library grounding
 * @param prompt The prompt to send to LLM
 * @return JSON response from LLM
 */
private static String callLLMOpenConnector(String prompt) {
    try {
        // Use Agentforce's Models API
        // This uses Salesforce's managed models (GPT-4, Claude, etc.)
        
        // Create the request
        aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
        
        // Set the model (use a standard Agentforce model)
        // Options: 'gpt-4o', 'gpt-4-turbo', 'claude-3-5-sonnet-20241022', etc.
        request.model = 'gpt-4o'; // or get from Custom Metadata
        
        // Set the prompt
        request.prompt = prompt;
        
        // Configure grounding with Data Library
        // The system will automatically search your Data Library based on the prompt
        request.grounding = new aiplatform.ModelsAPI.Grounding();
        request.grounding.enabled = true;
        request.grounding.source = 'DATA_LIBRARY'; // Use Data Library as source
        // Optionally specify the Knowledge Source ID if you have multiple sources
        // request.grounding.knowledgeSourceId = 'your-knowledge-source-id';
        
        // Optional: Configure grounding parameters
        request.grounding.topK = 5; // Number of relevant sections to retrieve
        request.grounding.relevanceThreshold = 0.7; // Minimum similarity score
        
        // Set other parameters
        request.temperature = 0.2; // Lower = more deterministic
        request.maxTokens = 2000; // Maximum response length
        
        // Make the API call
        aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
        
        // Return the response text
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

### 2.2 Alternative: Use Prompt Builder Template (Recommended for Production)

For better maintainability, create a **Prompt Template** in Prompt Builder and reference it:

**Step 2.2a: Create Prompt Template**

1. In Setup, search for **"Prompt Builder"** or **"Prompts"**
2. Click **New Prompt**
3. Configure:
   - **Name:** `NAICS_Matching_Prompt`
   - **Type:** `Flex` (or `Field Generation`)
   - **Model:** Select a standard model (e.g., GPT-4o)
4. In the prompt template, add:
   ```
   System: You are an expert in North American Industry Classification System (NAICS) 2017 codes.
   Your task is to analyze spending category descriptions and identify the most appropriate 6-digit NAICS code.
   
   You have access to the NAICS 2017 Definition File in the Knowledge Library.
   When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.
   
   User: Analyze these spending categories:
   Category 1: {category1}
   Category 2: {category2}
   Category 3: {category3}
   
   {!if(candidateCodes != null && candidateCodes.size() > 0, 
        'Focus your search in the Knowledge Library on these candidate NAICS codes: ' + candidateCodes + '\n\n', 
        '')}
   
   Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate 6-digit industry code.
   For each candidate code, retrieve its full definition including description, cross-references, and examples.
   
   Return your response in JSON format:
   {
     "suggestedNaicsCode": "6-digit code or null",
     "confidence": "HIGH|MEDIUM|LOW",
     "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",
     "alternativeNaicsCodes": ["code1", "code2"],
     "uncertaintyFactors": ["factor1", "factor2"]
   }
   ```
5. **Enable Knowledge Grounding:**
   - In the prompt settings, enable **"Use Knowledge Grounding"**
   - Select **"Data Library"** as the source
   - Select your NAICS PDF Knowledge Source
6. **Save** the prompt template

**Step 2.2b: Use Prompt Template in Apex**

```apex
/**
 * @description Call LLM via Prompt Template with Data Library grounding
 * @param category1 First spending category
 * @param category2 Second spending category
 * @param category3 Third spending category
 * @param candidateCodes Optional candidate NAICS codes
 * @return JSON response from LLM
 */
private static String callLLMOpenConnector(String prompt) {
    try {
        // Get the prompt template
        String templateName = 'NAICS_Matching_Prompt';
        
        // Create variables map for the template
        Map<String, Object> variables = new Map<String, Object>();
        variables.put('category1', category1);
        variables.put('category2', category2);
        variables.put('category3', category3);
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            variables.put('candidateCodes', candidateCodes);
        }
        
        // Invoke the prompt template
        aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
        request.promptTemplate = templateName;
        request.variables = variables;
        
        // Make the API call
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

## Step 3: Configure Grounding Parameters (Optional)

If you want to fine-tune the grounding behavior, you can configure these in the Models API call or in Prompt Builder:

- **Top K Retrievals:** `5-10` (number of relevant sections to retrieve)
- **Relevance Threshold:** `0.7` (minimum similarity score, 0.0-1.0)
- **Max Context Length:** `4000` tokens (adjust based on model limits)

## Step 4: Test the Integration

### 4.1 Test in Apex Anonymous Window

```apex
// Test the LLM service
Id testItemId = 'a0X...'; // Use a real Scope3PcmtItem ID

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);
System.debug('Status: ' + result.status);
System.debug('Recommended NAICS: ' + result.recommendedNaicsCode);
System.debug('Confidence: ' + result.confidenceScore);
System.debug('Reasoning: ' + result.reasoning);
```

### 4.2 Test Knowledge Grounding

1. Use **Agentforce Simulator** (if available in your org)
2. Test your prompt template with sample spending categories
3. Check the response details to see:
   - What sections were retrieved from the PDF
   - How they were injected into the context
   - The final prompt sent to LLM

### 4.3 Verify Response Format

The LLM should return JSON in this format:
```json
{
  "suggestedNaicsCode": "541211",
  "confidence": "HIGH",
  "reasoning": "The spending categories indicate accounting services...",
  "alternativeNaicsCodes": ["541219", "541211"],
  "uncertaintyFactors": []
}
```

## Step 5: Troubleshooting

### Issue: "Models API not available" or "Class not found"

**Solution:**
- Ensure Agentforce is enabled in your org
- Check that you have the Models API enabled
- Verify your API version supports `aiplatform` namespace

### Issue: "Knowledge Library not found" or "No relevant sections retrieved"

**Solution:**
- Verify PDF is uploaded and indexed in Data Library
- Check that grounding is enabled in your prompt template or API call
- Ensure the prompt mentions "Knowledge Library" or "Data Library"
- Try explicitly naming the document in the prompt

### Issue: "Invalid model name"

**Solution:**
- Use standard model names: `gpt-4o`, `gpt-4-turbo`, `claude-3-5-sonnet-20241022`
- Check available models in your org's Prompt Builder
- Verify the model is enabled for your org

### Issue: "Timeout" or "Request too long"

**Solution:**
- Reduce `maxTokens` in request
- Reduce `topK` in grounding settings
- Use pre-filtering to narrow candidate codes
- Increase timeout if available in API settings

## When Would You Need LLM Open Connector?

You only need to configure a **custom LLM Open Connector** if:

1. **Specific Model Requirements:** You need a model that Salesforce doesn't offer natively (e.g., Mistral, Llama 3, Cohere, or a fine-tuned model)
2. **Custom Hosting:** Your organization requires the model hosted on specific infrastructure (your own VPC, AWS Bedrock, Azure OpenAI) for compliance/data residency
3. **Proprietary Models:** You have a custom, in-house model you want to use

**For most use cases, including NAICS matching, the standard Agentforce models with Data Library grounding are sufficient and much simpler!**

## Comparison: Standard Models vs. Custom Connector

| Feature | Standard Models (This Guide) | Custom LLM Open Connector |
|---------|------------------------------|---------------------------|
| **Setup Effort** | Low (Just upload PDF) | High (API keys, endpoints, etc.) |
| **Model Choice** | GPT-4, Claude, Google (managed) | Any model (Mistral, Llama, custom) |
| **Grounding** | Native via Data Library | Custom implementation |
| **Security** | Managed by Einstein Trust Layer | You manage external endpoint |
| **Billing** | Einstein Requests (usage-based) | External provider + Salesforce |
| **Best For** | Most RAG tasks | Specialized/custom models |

## Next Steps

1. ✅ Upload NAICS PDF to Data Library (Step 1)
2. ✅ Update LLMService.cls to use Models API (Step 2)
3. ✅ Test the integration (Step 4)
4. ✅ Deploy to production
5. ✅ Monitor performance and adjust parameters

## Additional Resources

- [Get Started with Models and Prompts](https://developer.salesforce.com/docs/ai/agentforce/guide/models-get-started.html)
- [Models API Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html)
- [Access Models API with Apex](https://developer.salesforce.com/docs/ai/agentforce/guide/access-models-api-with-apex.html)
- [Prompt Builder Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/prompt-builder.html)

---

**Note:** The exact API syntax may vary slightly depending on your Salesforce org's Agentforce version. Refer to the latest Salesforce documentation for your specific API version.
