# How to Enable Knowledge Grounding for USEEIO_Reference
## Step-by-Step Guide for createGenerations API

## Overview

Since you're using the `createGenerations` API (not Prompt Builder templates), Knowledge Grounding needs to be configured in the API request itself. There are a few ways to do this:

## Method 1: Configure in the API Request (Recommended)

Update the `LLMService.cls` to include grounding configuration in the request body.

### Step 1: Check Available Grounding Properties

First, let's see what grounding options are available in your org. Run this in Developer Console:

```apex
// Check what properties are available on GenerationRequest
aiplatform.ModelsAPI_GenerationRequest req = new aiplatform.ModelsAPI_GenerationRequest();
req.prompt = 'Test prompt';

// Try to see what properties exist
// Look for: grounding, knowledgeSource, dataLibrary, etc.
System.debug('Request object: ' + JSON.serialize(req));
```

### Step 2: Update LLMService.cls

Based on what you find, you may need to add grounding configuration. Common approaches:

**Option A: If GenerationRequest has grounding properties:**
```apex
aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
requestBody.prompt = promptText;

// Add grounding configuration
requestBody.grounding = new aiplatform.ModelsAPI_Grounding();
requestBody.grounding.enabled = true;
requestBody.grounding.source = 'DATA_LIBRARY';
requestBody.grounding.knowledgeSourceId = 'USEEIO_Reference';
```

**Option B: If grounding is on the main request:**
```apex
aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

// Add grounding to request
request.grounding = new aiplatform.ModelsAPI_Grounding();
request.grounding.enabled = true;
request.grounding.source = 'DATA_LIBRARY';
request.grounding.knowledgeSourceId = 'USEEIO_Reference';
```

**Option C: If grounding uses different property names:**
```apex
// Some orgs might use:
requestBody.knowledgeSource = 'USEEIO_Reference';
// or
requestBody.dataLibrary = 'USEEIO_Reference';
// or
requestBody.useKnowledgeGrounding = true;
```

## Method 2: Configure at Model Level

Some orgs configure grounding at the model level rather than per-request.

### Step 1: Check Model Settings

1. Go to **Setup** → Search **"AI Models"** or **"Einstein Models"**
2. Find your model: `sfdc_ai__DefaultOpenAIGPT4OmniMini`
3. Check if there's a **"Knowledge Grounding"** or **"Data Library"** section
4. Enable grounding and select `USEEIO_Reference`

## Method 3: Use Prompt Builder Template (Alternative)

If grounding is easier in Prompt Builder, you could:

1. Create the Prompt Builder template with Knowledge Grounding enabled
2. Use a different API method to call the template (if available)
3. Or keep using `createGenerations` but reference the template's grounding settings

## Method 4: Verify Data Library is Ready

Before enabling grounding, make sure your Data Library is properly set up:

### Step 1: Check Data Library Status

1. Go to **Setup** → Search **"Data Library"** or **"Agentforce Studio"**
2. Find `USEEIO_Reference`
3. Verify:
   - ✅ Status is **"Indexed"** or **"Complete"**
   - ✅ Search Index is ready
   - ✅ Document is accessible

### Step 2: Get the Exact API Name

1. In Data Library, click on `USEEIO_Reference`
2. Note the **API Name** or **Developer Name**
3. Use this exact name in your grounding configuration

## Quick Test Script

Run this in Developer Console to test grounding:

```apex
// Test grounding configuration
try {
    aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
    request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    
    aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
    requestBody.prompt = 'Search the Knowledge Library (USEEIO_Reference) for information about NAICS code 423320. What is this industry?';
    
    // Try adding grounding (uncomment the approach that works)
    // Option 1:
    // requestBody.grounding = new aiplatform.ModelsAPI_Grounding();
    // requestBody.grounding.enabled = true;
    // requestBody.grounding.source = 'DATA_LIBRARY';
    // requestBody.grounding.knowledgeSourceId = 'USEEIO_Reference';
    
    // Option 2:
    // requestBody.knowledgeSource = 'USEEIO_Reference';
    
    request.body = requestBody;
    
    aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
    aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
    
    System.debug('Response: ' + response.Code200.generation.generatedText);
    
    // Check if response mentions content from your Data Library
    if (response.Code200.generation.generatedText.contains('423320') || 
        response.Code200.generation.generatedText.contains('NAICS')) {
        System.debug('✓ Grounding appears to be working!');
    } else {
        System.debug('⚠ Response may not be using grounding - check configuration');
    }
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Try different grounding property names');
}
```

## Troubleshooting

### "Property does not exist: grounding"
- Try different property names (see Option C above)
- Check if grounding is configured at model level instead
- Verify your org version supports grounding in createGenerations

### "Knowledge Source not found"
- Verify the exact API name of your Data Library
- Check if it's `USEEIO_Reference` or something else
- Ensure the Data Library is indexed and active

### "Grounding not working"
- Make sure the prompt explicitly mentions "Knowledge Library" or "USEEIO_Reference"
- Check that the Data Library status is "Indexed"
- Verify the model supports Knowledge Grounding
- Try enabling grounding at the model level instead

## Next Steps

1. **Run the test script** above to find the correct grounding syntax
2. **Update LLMService.cls** with the working grounding configuration
3. **Test in the UI** - the response should reference content from your Data Library

## Current Code Location

The code to update is in:
- `force-app/main/default/classes/LLMService.cls`
- Method: `callLLMOpenConnector()` (around line 125)
- Look for where `requestBody` is created

---

**Need Help?** Run the test script first to see what grounding properties are available in your org!
