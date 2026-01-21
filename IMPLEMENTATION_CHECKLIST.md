# Implementation Checklist
## Step-by-Step Guide to Complete the LLM Integration

## ✅ Completed Steps

- [x] Data Library `USEEIO_Reference` is indexed
- [x] All mock response code removed
- [x] Apex code updated to use Prompt Builder template approach
- [x] Variables prepared for template substitution

## 📋 Remaining Steps

### Step 1: Create Prompt Builder Template (15 minutes)

**Follow:** `PROMPT_BUILDER_SETUP.md` for detailed instructions

**Quick Summary:**
1. Go to Setup → Prompt Builder
2. Create new prompt named: `NAICS_Matching_Prompt`
3. Type: Flex
4. Model: GPT-4o (or any available)
5. Paste the prompt template (see PROMPT_BUILDER_SETUP.md)
6. **CRITICAL:** Enable Knowledge Grounding → Select USEEIO_Reference
7. Save

### Step 2: Find the Correct Models API Syntax (5 minutes)

The Apex code needs the exact API syntax for your org. Try these methods:

**Option A: Check Developer Console**
1. Open Developer Console
2. Go to Execute Anonymous
3. Try this code:
```apex
// Test 1: Check if Request class exists
aiplatform.ModelsAPI.Request req = new aiplatform.ModelsAPI.Request();
System.debug('Request class works');

// Test 2: Check if invoke method exists
req.promptTemplate = 'NAICS_Matching_Prompt';
Map<String, Object> vars = new Map<String, Object>{'category1' => 'test'};
req.variables = vars;
aiplatform.ModelsAPI.Response res = aiplatform.ModelsAPI.invoke(req);
System.debug('Response: ' + res.text);
```

**Option B: Check Salesforce Documentation**
- Visit: https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html
- Look for "Using Prompt Templates" section
- Check the exact class names and method signatures

**Option C: Check Prompt Builder**
- In Prompt Builder, look for "API Usage" or "Code Example" section
- Some orgs show example Apex code for calling the template

### Step 3: Update LLMService.cls (5 minutes)

Once you know the correct syntax:

1. Open `force-app/main/default/classes/LLMService.cls`
2. Find the `callLLMOpenConnector()` method (around line 102)
3. Uncomment **APPROACH 1** or **APPROACH 2** (whichever matches your org's syntax)
4. Adjust the code if needed based on what you found in Step 2
5. Remove or comment out the temporary error throw

**Example (if standard syntax works):**
```apex
try {
    aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
    request.promptTemplate = templateName;
    request.variables = variables;
    
    aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
    
    if (response != null && response.text != null) {
        return response.text;
    } else {
        throw new LLMServiceException('Empty response from Models API');
    }
} catch (Exception e) {
    throw new LLMServiceException('Models API call failed: ' + e.getMessage());
}
```

### Step 4: Deploy and Test (5 minutes)

1. Deploy the updated code:
   ```bash
   sf project deploy start --source-dir force-app/main/default/classes/LLMService.cls --target-org BVJan2026
   ```

2. Test in UI:
   - Go to a Scope3PcmtItem record
   - Click "Find Emissions Factor"
   - Should now use live LLM with Data Library grounding!

## 🔍 Troubleshooting

### "Template not found"
- Verify template name is exactly `NAICS_Matching_Prompt` (case-sensitive)
- Check template is saved and active in Prompt Builder

### "Knowledge Library not found"
- Verify Knowledge Grounding is enabled in template
- Check USEEIO_Reference is selected
- Ensure Data Library status is "Indexed" or "Complete"

### "Invalid type: aiplatform.ModelsAPI.Request"
- The API syntax may be different in your org version
- Try checking Developer Console for available classes
- Check Salesforce documentation for your API version (65.0)

### "Empty response"
- Check template is working in Prompt Builder test
- Verify variables are being passed correctly
- Check model has enough tokens

## 📚 Resources

- **Prompt Builder Setup:** `PROMPT_BUILDER_SETUP.md`
- **Quick Start Guide:** `QUICK_START_LLM.md`
- **Detailed Options:** `IMPLEMENT_LLM_API.md`
- **Salesforce Docs:** https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html

---

**Need Help?** 
1. Create the Prompt Builder template first (Step 1)
2. Then we can help you find the exact API syntax (Step 2)
