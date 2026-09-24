# Configuration Guide

Runtime behaviour — scoring thresholds and the LLM prompt template — is controlled by a single Custom Metadata record. No code changes or redeployment are required to adjust these values.

## Where the configuration lives

```
force-app/main/default/customMetadata/LLM_Config.Default.md-meta.xml
force-app/main/default/objects/LLM_Config__mdt/fields/   ← field definitions
```

The **Default** record is the only record read by Apex (`LLM_Config__mdt.getInstance('Default')`).

---

## Scoring thresholds

These fields control how the composite confidence score is calculated and when a match is auto-applied vs. sent to manual review.

| Field | Default | What it controls |
|---|---|---|
| `Auto_Apply_Threshold__c` | `0.7` | Minimum composite score for a match to be auto-applied. Items below this threshold are flagged as **Requires Review**. Also used as the lower bound of the review queue SOQL filters. |
| `LLM_Weight__c` | `0.6` | Weight given to the LLM confidence signal in the composite score (should sum to 1.0 with the two weights below). |
| `Match_Count_Weight__c` | `0.2` | Weight given to the number of matching factor set items found. |
| `Factor_Set_Weight__c` | `0.2` | Weight given to whether any factor set items were found at all. |
| `LLM_Score_High__c` | `0.9` | Raw score assigned when the LLM returns `HIGH` confidence. |
| `LLM_Score_Medium__c` | `0.6` | Raw score assigned when the LLM returns `MEDIUM` confidence. |
| `LLM_Score_Low__c` | `0.3` | Raw score assigned when the LLM returns `LOW` confidence. |

**Composite score formula:**

```
score = (llmRawScore × LLM_Weight__c)
      + (matchCountScore × Match_Count_Weight__c)
      + (factorSetScore × Factor_Set_Weight__c)
```

Where `matchCountScore` is `1.0` for a single match, `0.9` for multiple matches, and `0.0` for no matches; `factorSetScore` is `1.0` if any matches were found, `0.0` otherwise.

With the default weights, the **maximum achievable score is 0.94** (LLM HIGH + single match + factor set found). Setting `Auto_Apply_Threshold__c` above 0.94 means no items will ever auto-apply — useful for testing the review queue end-to-end.

### To change a threshold

1. Edit `LLM_Config.Default.md-meta.xml` and update the relevant `<value>` element.
2. Deploy only the metadata record:

```bash
sf project deploy start \
  --source-dir force-app/main/default/customMetadata/LLM_Config.Default.md-meta.xml \
  --target-org <your-org-alias>
```

The change takes effect immediately — no Apex recompile needed.

---

## Prompt template

The LLM is invoked via Einstein Prompt Builder. Two fields control which template is called:

| Field | Default | What it controls |
|---|---|---|
| `Prompt_Template_API_Name__c` | `NAICS_Matching_Prompt` | Developer name of the Flex template in Prompt Builder. |
| `Prompt_Invocation_Application_Name__c` | `PromptBuilderPreview` | `applicationName` passed to `ConnectApi.EinsteinLLM`. Try `PromptTemplateGenerationsInvocable` if invocation fails in your org. |

### To swap in a custom prompt template

1. Build and activate your new Flex template in **Setup → Prompt Builder**. It must expose the same input variables the Apex passes:
   - `Input:category1`, `Input:category2`, `Input:category3`
   - `Input:candidateCodes`, `Input:candidateDescriptions`
2. Note the template's **Developer Name** (not the label).
3. Update `Prompt_Template_API_Name__c` in `LLM_Config.Default.md-meta.xml` to that Developer Name.
4. Deploy the record (same command as above).

The template response must still return a JSON object with `naicsCode`, `confidence` (`HIGH`/`MEDIUM`/`LOW`), and `reasoning` keys — `LLMService` parses this structure. See [`CALL_PROMPT_TEMPLATE.md`](../llm-integration/CALL_PROMPT_TEMPLATE.md) for the full invocation pattern.

---

## Applying changes to production

Custom Metadata deployments follow standard Salesforce DX metadata deployment — include `LLM_Config.Default.md-meta.xml` in your package or use the `--source-dir` flag shown above. The field definitions under `objects/LLM_Config__mdt/fields/` only need to be deployed once when setting up a new org; after that, only the record file changes with each config update.
