# Finding the Correct Way to Invoke Prompt Builder Template
## Step-by-Step Guide

## Current Status

The code is currently using `createGenerations` API with a manually built prompt. This **doesn't actually invoke your Prompt Builder template** - it just sends text that references it.

## The Problem

To actually use your Prompt Builder template (with its Knowledge Grounding configuration), we need to invoke it through the Connect API, but the exact syntax varies by org version.

## Step 1: Check Prompt Builder for Code Examples

1. Go to **Setup** → **Prompt Builder**
2. Find your template: **NAICS_Matching_Prompt**
3. Click on it to open
4. Look for:
   - **"API Usage"** section
   - **"Code Example"** button
   - **"Apex Code"** tab
   - **"How to Use"** section

Many orgs show example Apex code for calling the template directly.

## Step 2: Test Connect API Syntax

Run this in Developer Console to find the correct syntax:

```apex
// Test 1: Check if Connect API classes exist
try {
    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    System.debug('✓ Connect API classes exist');
    
    // Try to see what properties are available
    // Check the object in debugger or try common property names
    
} catch (Exception e) {
    System.debug('✗ Connect API not available: ' + e.getMessage());
}

// Test 2: Check Prompt object structure
List<Prompt> prompts = [SELECT Id, DeveloperName FROM Prompt WHERE DeveloperName = 'NAICS_Matching_Prompt' LIMIT 1];
if (!prompts.isEmpty()) {
    System.debug('Template found: ' + prompts[0].Id);
    // Check if Prompt has any invoke methods or properties
}
```

## Step 3: Alternative Approaches

If Connect API doesn't work, try:

### Option A: Use Flow to Invoke Template
1. Create a Flow that invokes the Prompt Builder template
2. Call the Flow from Apex using `Flow.Interview`
3. This preserves Knowledge Grounding settings

### Option B: Query Prompt and Use Its Text
1. Query the Prompt object to get its prompt text
2. Substitute variables manually
3. Use `createGenerations` with the substituted text
4. **Note:** This loses the template's Knowledge Grounding configuration unless you add explicit references

### Option C: Check for Different API Methods
Some orgs might have:
- `Prompt.invoke()` method
- `EinsteinLLM.invokeTemplate()` method
- Different Connect API class names

## Step 4: Verify Template Exists

Make sure your template is actually saved:

1. Go to **Prompt Builder**
2. Verify **NAICS_Matching_Prompt** appears in the list
3. Check the **Developer Name** is exactly `NAICS_Matching_Prompt` (case-sensitive)
4. Ensure it's **Active** (not in draft)

## Next Steps

1. **Check Prompt Builder** for code examples (Step 1)
2. **Share the code example** you find, and I'll update the Apex code
3. **Or test the Connect API** syntax (Step 2) and share the results

The current code will work as a fallback (using createGenerations with manual prompt), but it won't use your template's Knowledge Grounding configuration. We need to find the correct way to invoke the template to preserve that.

---

**Quick Check:** In Prompt Builder, when you view your template, do you see any "API Usage" or "Code Example" section?
