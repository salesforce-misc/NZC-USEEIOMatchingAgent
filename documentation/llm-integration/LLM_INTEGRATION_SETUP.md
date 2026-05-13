# LLM Integration Setup Guide
## Step-by-Step Instructions for Configuring LLM Open Connector with Agentforce Data Library

## Overview

This guide walks you through configuring the LLM integration for the USEEIO Matching Agent. The solution uses:
- **LLM Open Connector** - Salesforce's framework for integrating external LLMs
- **Agentforce Data Library** - For grounding the LLM with NAICS definitions from the PDF

## Prerequisites

Before starting, ensure you have:
- ✅ Salesforce org with **Agentforce** enabled
- ✅ **LLM Open Connector** feature enabled
- ✅ Access to an LLM provider (OpenAI, Anthropic, etc.) with API credentials
- ✅ The **NAICS Codes 2017_Definition_File.pdf** ready to upload
- ✅ System Administrator or appropriate permissions

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
3. Note the **Knowledge Source Name** (you'll need this later)

**Troubleshooting:**
- If indexing fails, try re-uploading the PDF
- Ensure the PDF is not password-protected
- Check file size limits (typically 50MB max)

## Step 2: Configure LLM Open Connector

### 2.1 Access LLM Open Connector Setup

1. In Salesforce Setup, search for **"LLM Open Connector"** in Quick Find
2. Click on **LLM Open Connector** or **LLM Providers**
3. You should see a list of configured LLM providers (if any)

### 2.2 Create New LLM Provider Connection

1. Click **New** or **Add LLM Provider**
2. Select your LLM provider:
   - **OpenAI** (GPT-4, GPT-3.5)
   - **Anthropic** (Claude)
   - **Amazon Bedrock**
   - **Azure OpenAI**
   - **Custom** (for other providers)

### 2.3 Configure Provider Settings

**For OpenAI:**
1. **Provider Name:** `USEEIO_Matching_LLM` (or your preferred name)
2. **API Endpoint:** `https://api.openai.com/v1/chat/completions`
3. **API Key:** Enter your OpenAI API key (store securely)
4. **Model:** Select model (e.g., `gpt-4`, `gpt-4-turbo-preview`, `gpt-3.5-turbo`)
5. **Temperature:** `0.2` (lower = more deterministic, good for classification)
6. **Max Tokens:** `2000` (adjust based on expected response length)

**For Anthropic (Claude):**
1. **Provider Name:** `USEEIO_Matching_LLM`
2. **API Endpoint:** `https://api.anthropic.com/v1/messages`
3. **API Key:** Enter your Anthropic API key
4. **Model:** `claude-3-opus-20240229` or `claude-3-sonnet-20240229`
5. **Temperature:** `0.2`
6. **Max Tokens:** `2000`

**For Custom Providers:**
- Follow your provider's API documentation
- Ensure the API supports chat completion format
- Configure authentication (API key, OAuth, etc.)

### 2.4 Enable Knowledge Grounding

**Critical Step:** This connects the LLM to your Data Library.

1. In the LLM Provider configuration, find **"Knowledge Grounding"** or **"RAG Settings"**
2. Enable **"Use Knowledge Grounding"** or **"Enable RAG"**
3. Select **"Agentforce Data Library"** or **"Knowledge Sources"** as the source
4. Select the **Knowledge Source** containing your NAICS PDF
   - This should match the name from Step 1.3
5. Configure grounding parameters:
   - **Top K Retrievals:** `5-10` (number of relevant sections to retrieve)
   - **Relevance Threshold:** `0.7` (minimum similarity score, 0.0-1.0)
   - **Max Context Length:** `4000` tokens (adjust based on model limits)
6. **Save** the configuration

### 2.5 Test the Connection

1. In LLM Open Connector, find your configured provider
2. Click **Test Connection** or **Test**
3. Verify the connection succeeds
4. If it fails, check:
   - API key is correct
   - Network/firewall allows outbound connections
   - Provider endpoint is accessible

## Step 3: Create Named Credential (Optional but Recommended)

For better security and easier configuration:

### 3.1 Create Named Credential

1. In Setup, search for **"Named Credentials"**
2. Click **New Named Credential**
3. Configure:
   - **Label:** `USEEIO_LLM_Provider`
   - **Name:** `USEEIO_LLM_Provider` (API name)
   - **URL:** Your LLM provider endpoint
   - **Identity Type:** Named Principal
   - **Authentication Protocol:** OAuth 2.0 or Password Authentication
   - **API Key:** Store your API key here (more secure than hardcoding)

### 3.2 Reference in Apex

You can reference this Named Credential in your Apex code using:
```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:USEEIO_LLM_Provider/v1/chat/completions');
```

## Step 4: Implement Apex LLM Service

### 4.1 Update LLMService.cls

Replace the placeholder `callLLMOpenConnector` method with actual implementation:

```apex
/**
 * @description Call LLM via LLM Open Connector
 * @param prompt The prompt to send to LLM
 * @return JSON response from LLM
 */
private static String callLLMOpenConnector(String prompt) {
    try {
        // Option 1: Use LLM Open Connector API (if available)
        // This requires the LLM Open Connector to be configured in Setup
        
        // Option 2: Direct HTTP callout to LLM provider
        // Use this if LLM Open Connector API is not available in Apex
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + getApiKey());
        req.setEndpoint(getLLMEndpoint());
        req.setTimeout(120000); // 2 minutes timeout
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('model', getModelName());
        requestBody.put('temperature', 0.2);
        requestBody.put('max_tokens', 2000);
        
        // Build messages array
        List<Map<String, String>> messages = new List<Map<String, String>>();
        
        // System message
        Map<String, String> systemMsg = new Map<String, String>();
        systemMsg.put('role', 'system');
        systemMsg.put('content', 'You are an expert in NAICS 2017 codes. You have access to the NAICS 2017 Definition File in the Knowledge Library.');
        messages.add(systemMsg);
        
        // User message (with prompt)
        Map<String, String> userMsg = new Map<String, String>();
        userMsg.put('role', 'user');
        userMsg.put('content', prompt);
        messages.add(userMsg);
        
        requestBody.put('messages', messages);
        
        // Convert to JSON
        req.setBody(JSON.serialize(requestBody));
        
        // Make callout
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new LLMServiceException('LLM API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
    } catch (Exception e) {
        throw new LLMServiceException('LLM callout error: ' + e.getMessage());
    }
}

/**
 * @description Get API key from Custom Metadata or Named Credential
 * @return API key string
 */
private static String getApiKey() {
    // Option 1: From Custom Metadata Type
    // LLM_Config__mdt config = LLM_Config__mdt.getInstance('Default');
    // return config.API_Key__c;
    
    // Option 2: From Named Credential (if using OAuth)
    // return '{!$Credential.USEEIO_LLM_Provider}';
    
    // Option 3: From Custom Setting (less secure)
    // LLM_Config__c config = LLM_Config__c.getInstance();
    // return config.API_Key__c;
    
    // For now, throw exception - must be configured
    throw new LLMServiceException('API key not configured. Please set up Custom Metadata or Named Credential.');
}

/**
 * @description Get LLM endpoint URL
 * @return Endpoint URL
 */
private static String getLLMEndpoint() {
    // Option 1: From Custom Metadata
    // LLM_Config__mdt config = LLM_Config__mdt.getInstance('Default');
    // return config.Endpoint__c;
    
    // Option 2: From Named Credential
    // return 'callout:USEEIO_LLM_Provider/v1/chat/completions';
    
    // Default endpoints
    // return 'https://api.openai.com/v1/chat/completions';
    // return 'https://api.anthropic.com/v1/messages';
    
    throw new LLMServiceException('LLM endpoint not configured.');
}

/**
 * @description Get model name
 * @return Model name string
 */
private static String getModelName() {
    // Option 1: From Custom Metadata
    // LLM_Config__mdt config = LLM_Config__mdt.getInstance('Default');
    // return config.Model__c;
    
    // Default models
    // return 'gpt-4';
    // return 'claude-3-opus-20240229';
    
    throw new LLMServiceException('Model name not configured.');
}
```

### 4.2 Create Custom Metadata Type for Configuration (Recommended)

**Create Custom Metadata Type: `LLM_Config__mdt`**

1. In Setup, go to **Custom Metadata Types**
2. Click **New Custom Metadata Type**
3. Configure:
   - **Label:** `LLM Config`
   - **Plural Label:** `LLM Configs`
   - **Object Name:** `LLM_Config`
4. Add fields:
   - **API_Key__c** (Text, 255) - Encrypted text field recommended
   - **Endpoint__c** (URL, 255)
   - **Model__c** (Text, 100)
   - **Temperature__c** (Number, 3, 2)
   - **Max_Tokens__c** (Number, 10, 0)
5. Create a **Default** record:
   - **Label:** `Default`
   - **API_Key__c:** Your API key
   - **Endpoint__c:** Your LLM endpoint
   - **Model__c:** Your model name
   - **Temperature__c:** `0.2`
   - **Max_Tokens__c:** `2000`

### 4.3 Update Remote Site Settings

If making direct HTTP callouts (not using Named Credential):

1. In Setup, search for **"Remote Site Settings"**
2. Click **New Remote Site**
3. Configure:
   - **Remote Site Name:** `LLM_Provider` (e.g., `OpenAI_API`)
   - **Remote Site URL:** Your LLM provider URL (e.g., `https://api.openai.com`)
   - **Active:** Checked
4. **Save**

## Step 5: Configure Knowledge Grounding in Prompt

The prompt in `LLMService.buildPrompt()` already includes Knowledge Library references. Ensure:

1. The prompt mentions **"Knowledge Library"** or **"Data Library"**
2. Instructions tell LLM to **"search the Knowledge Library"**
3. The prompt references the NAICS document

**Example prompt structure (already in code):**
```
System: You are an expert in NAICS 2017 codes. 
You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library.
When analyzing spending categories, search the Knowledge Library for relevant NAICS definitions.

User: Analyze these spending categories:
Category 1: {category1}
Category 2: {category2}
Category 3: {category3}

Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate 6-digit industry code.
```

## Step 6: Test the Integration

### 6.1 Test in Apex Anonymous Window

```apex
// Test the LLM service
Id testItemId = 'a0X...'; // Use a real Scope3PcmtItem ID

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);
System.debug('Status: ' + result.status);
System.debug('Recommended NAICS: ' + result.recommendedNaicsCode);
System.debug('Confidence: ' + result.confidenceScore);
System.debug('Reasoning: ' + result.reasoning);
```

### 6.2 Test Knowledge Grounding

1. Use **Agentforce Simulator** (if available)
2. Create a test prompt referencing the Knowledge Library
3. Check the response details to see:
   - What sections were retrieved from the PDF
   - How they were injected into the context
   - The final prompt sent to LLM

### 6.3 Verify Response Format

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

## Step 7: Troubleshooting

### Issue: "LLM integration not yet configured"

**Solution:**
- Ensure `getApiKey()`, `getLLMEndpoint()`, and `getModelName()` methods return actual values
- Check Custom Metadata Type is created and has a Default record
- Verify API key is correct

### Issue: "Callout failed" or "401 Unauthorized"

**Solution:**
- Verify API key is correct and not expired
- Check Remote Site Settings includes the provider URL
- Ensure Named Credential (if used) is configured correctly

### Issue: "Knowledge Library not found" or "No relevant sections retrieved"

**Solution:**
- Verify PDF is uploaded and indexed in Data Library
- Check Knowledge Source is selected in LLM Open Connector settings
- Ensure Knowledge Grounding is enabled
- Try explicitly naming the document in the prompt

### Issue: "Timeout" or "Request too long"

**Solution:**
- Reduce `Max_Tokens` in request
- Reduce `Top K Retrievals` in grounding settings
- Use pre-filtering to narrow candidate codes
- Increase timeout in HttpRequest (currently 120000ms)

### Issue: "Invalid JSON response"

**Solution:**
- Check LLM response format matches expected JSON
- Add error handling in `parseLLMResponse()` method
- Verify LLM model supports structured output
- Consider using function calling if available

## Step 8: Production Considerations

### 8.1 Security

- ✅ Store API keys in **Custom Metadata Types** (encrypted fields) or **Named Credentials**
- ✅ Never hardcode API keys in Apex
- ✅ Use **Remote Site Settings** to restrict outbound connections
- ✅ Implement **rate limiting** to prevent API abuse

### 8.2 Performance

- ✅ Use **pre-filtering** (KeywordMatchingService) to reduce LLM calls
- ✅ **Cache** frequently accessed NAICS definitions (if applicable)
- ✅ Implement **retry logic** for transient failures
- ✅ Monitor **API usage** and costs

### 8.3 Error Handling

- ✅ Implement **graceful degradation** (fallback to keyword matching)
- ✅ Log errors for debugging
- ✅ Return meaningful error messages to users
- ✅ Handle rate limits and quota exceeded errors

### 8.4 Monitoring

- ✅ Track LLM API call success/failure rates
- ✅ Monitor response times
- ✅ Log confidence scores for quality analysis
- ✅ Track costs per match

## Next Steps

1. ✅ Complete Steps 1-6 to configure the integration
2. ✅ Test with real Scope3PcmtItem records
3. ✅ Monitor performance and adjust parameters
4. ✅ Deploy to production org
5. ✅ Train users on the matching agent

## Additional Resources

- [Salesforce LLM Open Connector Documentation](https://help.salesforce.com/)
- [Agentforce Data Library Guide](https://help.salesforce.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com/)

---

**Note:** The exact steps may vary slightly depending on your Salesforce org's configuration and the LLM provider you choose. Refer to your provider's documentation for specific API requirements.
