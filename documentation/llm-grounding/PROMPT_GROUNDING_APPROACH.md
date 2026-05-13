# Knowledge Grounding via Prompt Template
## Current Best Practice for createGenerations API

## Overview

Based on the most current Salesforce documentation, **Knowledge Grounding is triggered by how you reference the Data Library in the prompt text itself**, rather than through explicit API properties. The system automatically detects references to Knowledge Libraries and Data Libraries and enables grounding.

## How It Works

When you include specific references to your Data Library in the prompt, the Agentforce system:

1. **Detects the reference** - Recognizes mentions of "Knowledge Library", "Data Library", or specific source names
2. **Enables automatic grounding** - Activates RAG (Retrieval-Augmented Generation) for that source
3. **Retrieves relevant content** - Searches the indexed Data Library based on your prompt
4. **Injects context** - Adds retrieved sections to the prompt context before sending to the LLM

## Prompt Structure for Grounding

### Key Elements to Include

1. **Explicit Data Library Reference**
   ```
   "You have access to the [document name] in the Agentforce Knowledge Library."
   "The Knowledge Library contains the document [name] in the Data Library source named [source name]."
   ```

2. **Instruction to Search**
   ```
   "Search the Knowledge Library (USEEIO_Reference) for..."
   "Use the Knowledge Library to find..."
   "Retrieve information from the Data Library..."
   ```

3. **Specific Source Name**
   ```
   "Knowledge Library (USEEIO_Reference)"
   "Data Library source USEEIO_Reference"
   ```

### Example Prompt Structure

```
System: You are an expert in [domain]. 
You have access to [document name] in the Agentforce Knowledge Library. 
The Knowledge Library contains the document "[filename]" in the Data Library source named "[source name]". 
When analyzing [task], you must search this Knowledge Library for relevant information.

User: [Your query]

IMPORTANT: You must use the Knowledge Library ([source name]) to find [information]. 
Search this document for [what you need].
```

## Current Implementation

The `buildPromptFromTemplate()` method in `LLMService.cls` now includes:

✅ **Explicit Data Library reference** - Mentions "USEEIO_Reference" by name  
✅ **Document reference** - References "NAICS Codes 2017_Definition_File.pdf"  
✅ **Search instructions** - Explicitly instructs to "search the Knowledge Library"  
✅ **Multiple references** - Reinforces the grounding trigger throughout the prompt

## Verification

To verify grounding is working:

1. **Check the response** - Should reference specific content from your Data Library
2. **Look for citations** - Some models include source references
3. **Test with specific queries** - Ask about content you know is in the PDF
4. **Compare responses** - With vs. without Knowledge Library references

## Testing

Run this test to verify grounding:

```apex
// Test if grounding is working
aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
requestBody.prompt = 'Search the Knowledge Library (USEEIO_Reference) for NAICS code 423320. What is the full industry description for this code?';

request.body = requestBody;
aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);

System.debug('Response: ' + response.Code200.generation.generatedText);

// If response contains specific details about NAICS 423320 from the PDF, grounding is working!
```

## Best Practices

1. **Be explicit** - Clearly state the Data Library source name
2. **Use multiple references** - Reinforce the grounding trigger throughout the prompt
3. **Include document name** - Reference the specific document when possible
4. **Use imperative language** - "Search", "Retrieve", "Find" trigger grounding better than passive language
5. **Be specific** - Mention what type of information to retrieve

## Troubleshooting

### Grounding Not Working

**Symptoms:**
- Response doesn't reference content from Data Library
- Generic responses without specific details
- No citations or source references

**Solutions:**
1. **Strengthen prompt references** - Add more explicit mentions of the Data Library
2. **Verify Data Library status** - Ensure it's fully indexed
3. **Check source name** - Use exact API name (case-sensitive)
4. **Test with simpler query** - Try a direct question about known content
5. **Check model capabilities** - Some models have better grounding support

### Response Too Generic

**If the LLM gives generic answers:**
- Add more specific instructions: "Retrieve the exact definition from the Knowledge Library"
- Request citations: "Include the specific section from the NAICS definition"
- Be more directive: "You MUST use the Knowledge Library, do not use general knowledge"

## Alternative: Model-Level Configuration

Some orgs may also need to enable grounding at the model level:

1. Go to **Setup** → **AI Models** or **Einstein Models**
2. Find your model configuration
3. Enable **Knowledge Grounding** or **Data Library Access**
4. Select **USEEIO_Reference** as an allowed source

But the primary method is through prompt references as described above.

---

**Current Status:** The prompt in `LLMService.cls` is now optimized for automatic Knowledge Grounding via prompt references.
