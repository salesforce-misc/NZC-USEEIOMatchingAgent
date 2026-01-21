# Prompt Builder Template Setup Guide
## Step-by-Step Instructions for Creating the NAICS Matching Prompt

## Overview

This guide walks you through creating a Prompt Builder template that will:
- Use your indexed Data Library (`USEEIO_Reference`) for grounding
- Accept spending category variables
- Return structured JSON with NAICS code suggestions

## Step 1: Navigate to Prompt Builder

1. In Salesforce, click the **Setup** gear icon (⚙️) in the top right
2. In the Quick Find box, type: **"Prompt Builder"** or **"Prompts"**
3. Click on **"Prompt Builder"** or **"Prompts"** from the results

**Alternative Path:**
- Go to **App Launcher** (9-dot menu)
- Search for **"Prompt Builder"**
- Click to open

## Step 2: Create New Prompt

1. Click the **"New Prompt"** button (or **"Create Prompt"**)
2. You'll see a prompt creation form

## Step 3: Configure Basic Settings

Fill in the following:

- **Name:** `NAICS_Matching_Prompt`
  - This is the Developer Name that will be used in Apex code
  - Make sure it matches exactly (case-sensitive)

- **Type:** Select **"Flex"** 
  - Flex prompts are the most flexible and support variables

- **Model:** Select a model from the dropdown
  - Recommended: **"GPT-4o"** or **"GPT-4 Turbo"**
  - Any available model will work

- **Description (optional):** 
  - "Matches corporate spending categories to NAICS 2017 codes using Data Library grounding"

## Step 4: Write the Prompt Template

In the **Prompt** text area, paste this template:

```
System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. Your task is to analyze spending category descriptions from corporate procurement systems and identify the most appropriate 6-digit NAICS industry code.

You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library (USEEIO_Reference). When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.

User: Analyze these spending categories:
Category 1: {category1}
Category 2: {category2}
Category 3: {category3}

Candidate NAICS codes to consider: {candidateCodes}

Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate 6-digit industry code. If candidate codes are provided, focus your search on those codes first. For each candidate code, retrieve its full definition including:
- Industry description
- Cross-references
- Examples
- What activities are included/excluded

Analyze the spending categories against the retrieved definitions and select the best match.

Return your response in JSON format:
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

**Important Notes:**
- The variables `{category1}`, `{category2}`, `{category3}`, and `{candidateCodes}` will be replaced with actual values from Apex
- The `{!IF(...)}` expression handles the optional candidate codes
- The prompt explicitly references "Knowledge Library" to trigger grounding

## Step 5: Enable Knowledge Grounding

This is the **critical step** that connects your Data Library:

1. Look for a section labeled **"Knowledge Grounding"** or **"Grounding"** in the prompt settings
2. Toggle **"Use Knowledge Grounding"** to **ON** (or check the checkbox)
3. Select **"Data Library"** as the source type
4. In the **Knowledge Source** dropdown, select **"USEEIO_Reference"**
   - This is your indexed Data Library containing the NAICS PDF

**Grounding Parameters (Optional):**
- **Top K:** `5` (number of relevant sections to retrieve)
- **Relevance Threshold:** `0.7` (minimum similarity score)

## Step 6: Configure Advanced Settings (Optional)

- **Temperature:** `0.2` (lower = more deterministic, good for classification)
- **Max Tokens:** `2000` (maximum response length)
- **Stop Sequences:** Leave empty

## Step 7: Save the Prompt

1. Click **"Save"** or **"Save & Close"**
2. Wait for the prompt to be saved
3. Note the **Developer Name** - it should be `NAICS_Matching_Prompt`

## Step 8: Verify the Template

1. After saving, you should see the prompt in your list
2. Click on it to verify:
   - ✅ Knowledge Grounding is enabled
   - ✅ USEEIO_Reference is selected as the source
   - ✅ Variables are correctly formatted (`{category1}`, etc.)

## Step 9: Test the Template (Optional)

You can test the template directly in Prompt Builder:

1. Click **"Test"** or **"Preview"** button
2. Enter test values:
   - category1: "Construction Equipment"
   - category2: "Rental"
   - category3: "Heavy Machinery"
   - candidateCodes: ["532412", "423320"]
3. Click **"Run"** or **"Generate"**
4. Verify it returns JSON with a suggested NAICS code

## Troubleshooting

### "Template not found" error in Apex
- Verify the Developer Name is exactly `NAICS_Matching_Prompt` (case-sensitive)
- Check that the prompt is saved and active

### "Knowledge Library not found" in response
- Verify Knowledge Grounding is enabled
- Check that USEEIO_Reference is selected
- Ensure the Data Library is fully indexed (status should be "Indexed" or "Complete")

### Variables not being replaced
- Verify variable names match exactly: `{category1}`, `{category2}`, `{category3}`, `{candidateCodes}`
- Check that variables are passed from Apex code

### Empty or invalid JSON response
- Check that the prompt includes the JSON format instructions
- Verify the model has enough tokens (increase Max Tokens if needed)
- Test the template directly in Prompt Builder first

## Next Steps

Once the template is created:

1. ✅ The Apex code in `LLMService.cls` is already updated to use this template
2. ✅ Deploy the updated code to your org
3. ✅ Test in the UI by clicking "Find Emissions Factor" on a Scope3PcmtItem record

The system will now:
- Call your Prompt Builder template
- Pass the spending categories as variables
- Use USEEIO_Reference Data Library for grounding
- Return structured JSON with NAICS code suggestions

---

**Need help?** Check the Apex code in `LLMService.cls` - the `callLLMOpenConnector()` method is already configured to use this template name.
