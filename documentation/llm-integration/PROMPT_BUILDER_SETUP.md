# Prompt Builder Template Setup Guide
## Step-by-Step Instructions for Creating the NAICS Matching Prompt

## Overview

This guide walks you through creating a Prompt Builder template that will:

- **Not** use a Data Library or Knowledge grounding (same idea as the original **Models API** path: prompt + model knowledge only).
- Accept spending categories and **candidate NAICS codes with factor-set descriptions** passed from Apex (the same data the old Apex assembled into the prompt string).
- Return structured JSON with NAICS code suggestions.

### How this matches the original Apex behavior

- **Prior successful matches (cache):** For a given spending-category combination, `USEEIOMatchingService` and bulk processing still use **`LLM_Response_Cache__c`** (and in-memory deduplication in batch) **before** calling the LLM. The Flex template runs only on **cache miss**—equivalent to skipping the API when the old code found a cached response.
- **No retrieval / PDF grounding:** The legacy implementation did **not** attach the NAICS PDF; it referenced “Knowledge Library” in text only. This template is written to rely on **public NAICS 2017 documentation as the model knows it**, plus the **candidate list and descriptions** supplied in the inputs.

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
  - "Maps procurement spending categories to NAICS 2017 using factor-set candidates and model knowledge (no Data Library grounding)"

## Step 3b: Define Flex template inputs (required for Apex)

Add **five** text inputs so they match what `LLMService` sends (prefix `Input:` in Apex). In Prompt Builder, create inputs whose **API names** are exactly:

| API name                | Type | Purpose                                                                  |
| ----------------------- | ---- | ------------------------------------------------------------------------ |
| `category1`             | Text | Spending category 1                                                      |
| `category2`             | Text | Spending category 2                                                      |
| `category3`             | Text | Spending category 3                                                      |
| `candidateCodes`        | Text | Comma-separated candidate NAICS codes (or `None provided`)               |
| `candidateDescriptions` | Text | Bullet list of code descriptions from the factor set (or `None provided`) |

Reference each input in the template body using your product’s merge syntax (often `{category1}` or `{{category1}}`—use whatever Prompt Builder shows for **Insert resource**).

If API names differ in your org, update the constants `IN_*` in [`LLMService.cls`](../../force-app/main/default/classes/LLMService.cls) to match **Input:YourApiName**.

## Step 4: Write the Prompt Template

In the **Prompt** text area, define instructions **only here** (not in Apex). This version **does not** assume Data Library or retriever access—align with the old high-success flow: strong candidate list + descriptions + NAICS expertise.

Example (adjust merge syntax to match Prompt Builder):

```
System: You are an expert in the North American Industry Classification System (NAICS) 2017. Your job is to map corporate procurement spending categories to the single best 6-digit NAICS industry code.

You are not connected to a live document index. Use your knowledge of NAICS 2017 as published in public documentation (e.g. official NAICS manual / Census sector descriptions). The application supplies optional candidate codes and short labels from its emissions factor database—when provided, those codes are in-scope for the customer’s factor set.

User: Spending categories to classify:
Category 1: {category1}
Category 2: {category2}
Category 3: {category3}

Candidate NAICS codes (comma-separated; may be "None provided"): {candidateCodes}

Emissions-factor database labels for those candidates (may be "None provided"):
{candidateDescriptions}

Rules:
1) If the candidate list is not empty and not "None provided", you MUST pick suggestedNaicsCode from that list only. Do not invent or substitute a different 6-digit code outside the list.
2) If there are no candidates, infer the best 6-digit NAICS 2017 code from the category text using standard NAICS definitions.
3) Use the candidate descriptions to disambiguate when multiple codes are plausible.
4) reasoning should cite NAICS industry concepts (what the code covers) and how they align with the spend text—not citations to a private PDF.

Return ONLY a single JSON object—no markdown fences, no commentary outside JSON:
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Concise justification using NAICS 2017 semantics and the candidate list when applicable",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

**Important notes**

- All instructional text lives in the template; Apex only passes the five input values.
- **Do not** enable Data Library grounding for this design (see Step 5).
- If Connect API returns input errors, verify input **API names** match the `Input:*` keys in `LLMService`.

## Step 5: Keep Knowledge / Data Library grounding OFF (recommended)

To mirror the original Apex + Models API behavior (high match rate without indexed grounding):

1. Find **Knowledge Grounding**, **Data Library**, or **Retriever** settings on the template.
2. Leave **grounding disabled** / **no Data Library** attached to this prompt.

Optional: If your org later enables grounding for a different template, use a **separate** template name; this project’s default metadata (`NAICS_Matching_Prompt`) assumes **no** retrieval.

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
   - ✅ Grounding / Data Library is **off** (unless you intentionally changed strategy)
   - ✅ Five inputs exist with API names above
   - ✅ Template body matches Step 4 intent

## Step 9: Test the Template (Optional)

You can test the template directly in Prompt Builder:

1. Click **"Test"** or **"Preview"** button
2. Enter test values:
   - category1: "Construction Equipment"
   - category2: "Rental"
   - category3: "Heavy Machinery"
   - candidateCodes: `532412, 423320` (or your org’s codes)
   - candidateDescriptions: lines like `- 532412: ...` if you want to simulate factor set text
3. Click **"Run"** or **"Generate"**
4. Verify it returns JSON with a suggested NAICS code

## Troubleshooting

### "Template not found" error in Apex

- Verify the Developer Name is exactly `NAICS_Matching_Prompt` (case-sensitive)
- Check that the prompt is saved and active

### Variables not being replaced

- Verify Flex input API names match: `category1`, `category2`, `category3`, `candidateCodes`, `candidateDescriptions`
- Apex sends `Input:category1`, etc.; those must map to the template inputs’ API names

### Empty or invalid JSON response

- Check that the prompt includes the JSON format instructions
- Verify the model has enough tokens (increase Max Tokens if needed)
- Test the template directly in Prompt Builder first

### Retriever / Data Library errors from Connect API

- Those usually appear only if grounding is **enabled** on the template. For this design, **disable** grounding. See [ISSUE_DESCRIPTION_FOR_EXPERTS.md](../implementation/ISSUE_DESCRIPTION_FOR_EXPERTS.md) for historical context.

## Next Steps

Once the template is created and active:

1. Deploy **Custom Metadata** `LLM_Config.Default` and Apex (`LLMService`, tests) to your org.
2. Confirm `LLM_Config__mdt` values (or override **Default** in Setup) for template name and `applicationName` if needed.
3. Test in Prompt Builder, then run a Scope3PcmtItem match in the UI.

The app will:

- Resolve **cache hits** in Apex before calling the template (same category hash + factor set as before).
- On miss, invoke the template via `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` with the five inputs.
- Parse the JSON completion in `LLMService.parseLLMResponse`.

---

**Need help?** See [`CALL_PROMPT_TEMPLATE.md`](CALL_PROMPT_TEMPLATE.md) and [`LLMService.cls`](../../force-app/main/default/classes/LLMService.cls).
