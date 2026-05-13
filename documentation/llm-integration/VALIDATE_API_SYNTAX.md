# How to Validate the Correct Models API Syntax
## Step-by-Step Guide to Find the Right Syntax for Your Org

## Method 1: Use Developer Console (Recommended - 5 minutes)

### Step 1: Open Developer Console

1. In Salesforce, click the **Setup** gear icon (⚙️)
2. In Quick Find, search for **"Developer Console"**
3. Click **"Developer Console"** to open it

**Alternative:** Press `Ctrl+E` (Windows) or `Cmd+E` (Mac) from anywhere in Salesforce

### Step 2: Open Execute Anonymous Window

1. In Developer Console, go to **Debug** → **Open Execute Anonymous Window**
   - Or press `Ctrl+Shift+E` (Windows) or `Cmd+Shift+E` (Mac)

### Step 3: Run the Test Script

1. Open the file: `scripts/apex/test_models_api_syntax.apex`
2. Copy the entire contents
3. Paste into the Execute Anonymous Window
4. Check **"Open Log"** checkbox (to see debug output)
5. Click **"Execute"**

### Step 4: Review the Results

Look at the Debug Log output. You should see:

**✅ If syntax is correct:**
```
✓ ModelsAPI class found
✓ Request class created successfully
✓ promptTemplate property works
✓ variables property works
✓ invoke() method works!
```

**❌ If syntax is wrong:**
```
✗ Request class syntax error: Invalid type: aiplatform.ModelsAPI.Request
```

**⚠️ If template doesn't exist yet:**
```
✓ invoke() syntax OK, but call failed (likely template not found)
```
This is OK - it means the syntax is correct, you just need to create the template.

## Method 2: Check Salesforce Documentation

1. Visit: https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html
2. Look for the **"Using Prompt Templates"** section
3. Check the exact class names and method signatures
4. Compare with your org's API version (65.0 in your project)

## Method 3: Check Prompt Builder for Code Examples

Some orgs show example Apex code in Prompt Builder:

1. Go to **Setup** → **Prompt Builder**
2. Create or open a prompt template
3. Look for **"API Usage"**, **"Code Example"**, or **"Apex Code"** section
4. Some prompts show example code for calling them

## Method 4: Try the Standard Syntax Directly

If the test script shows syntax errors, try this simplified test:

```apex
// Minimal test - just check if classes exist
try {
    aiplatform.ModelsAPI.Request req = new aiplatform.ModelsAPI.Request();
    System.debug('Request class works');
    
    req.promptTemplate = 'NAICS_Matching_Prompt';
    Map<String, Object> vars = new Map<String, Object>{'category1' => 'test'};
    req.variables = vars;
    
    aiplatform.ModelsAPI.Response res = aiplatform.ModelsAPI.invoke(req);
    System.debug('Success! Response: ' + res.text);
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Line: ' + e.getLineNumber());
}
```

## Common Syntax Variations

### Standard Syntax (Most Common)
```apex
aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
request.promptTemplate = 'NAICS_Matching_Prompt';
request.variables = variables;
aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
String result = response.text;
```

### Alternative 1: Different Method Name
```apex
// Some orgs might use:
aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invokeTemplate('NAICS_Matching_Prompt', variables);
```

### Alternative 2: Different Class Structure
```apex
// Some orgs might nest classes differently:
aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
// ... rest same
```

## What to Do Based on Results

### ✅ If Standard Syntax Works

1. Open `LLMService.cls`
2. Find `callLLMOpenConnector()` method (around line 102)
3. Uncomment **APPROACH 1** (lines 132-148)
4. Deploy and test

### ❌ If Standard Syntax Doesn't Work

1. Check the error message in the debug log
2. Look for the exact class/method names mentioned
3. Check Salesforce documentation for your API version
4. Try the alternative syntaxes above
5. Update `callLLMOpenConnector()` with the working syntax

### ⚠️ If Syntax Works But Call Fails

This usually means:
- The Prompt Builder template doesn't exist yet
- Create the template first (see `PROMPT_BUILDER_SETUP.md`)
- Then the API call should work

## Quick Reference

**Test Script Location:** `scripts/apex/test_models_api_syntax.apex`

**Code to Update:** `force-app/main/default/classes/LLMService.cls` (line 102)

**Expected Variables:**
- `category1` (String)
- `category2` (String)
- `category3` (String)
- `candidateCodes` (String - comma-separated)

## Troubleshooting

### "Invalid type: aiplatform.ModelsAPI.Request"
- The API structure may be different in your org version
- Check Salesforce documentation for API version 65.0
- Try alternative syntaxes

### "Method does not exist: invoke"
- Check if method name is different (e.g., `invokeTemplate`)
- Look at Salesforce documentation for exact method names

### "Template not found"
- This is OK - it means syntax is correct
- Create the Prompt Builder template first
- Then the call should work

---

**Next Step:** Once you find the correct syntax, update `LLMService.cls` and deploy!
