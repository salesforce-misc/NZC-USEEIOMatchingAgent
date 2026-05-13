# Calling the NAICS Prompt Template from Apex

`LLMService.suggestNaicsCode` invokes the Flex template configured in **Custom Metadata** (`LLM_Config__mdt` record **Default**) using **`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`**.

**Design:** No Data Library grounding—the template uses **candidate codes + descriptions from Apex** and the model’s **NAICS 2017 knowledge**, matching the old Models API approach. **Cache hits** (`LLM_Response_Cache__c` / batch dedupe) are still handled in Apex **before** this call.

## Configuration

| Setting | Source | Purpose |
| -------- | ------ | -------- |
| Template API name | `LLM_Config__mdt.Prompt_Template_API_Name__c` | Developer name of the Prompt Builder template (default `NAICS_Matching_Prompt`) |
| Application name | `LLM_Config__mdt.Prompt_Invocation_Application_Name__c` | `EinsteinLlmAdditionalConfigInput.applicationName` (default `PromptBuilderPreview`). If invocation fails, try `PromptTemplateGenerationsInvocable` per your org. |

## Apex pattern (same as `LLMService`)

```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
promptInput.isPreview = false;
promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
promptInput.additionalConfig.numGenerations = 1;
promptInput.inputParams = new Map<String, ConnectApi.WrappedValue>{
    'Input:category1' => wrap('...'),
    'Input:category2' => wrap('...'),
    'Input:category3' => wrap('...'),
    'Input:candidateCodes' => wrap('541211, 541219'),
    'Input:candidateDescriptions' => wrap('- 541211: ...')
};

ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('NAICS_Matching_Prompt', promptInput);

String jsonText = result.generations[0].text;
```

`Input:*` keys **must match** the Flex template input API names in Prompt Builder (see [PROMPT_BUILDER_SETUP.md](PROMPT_BUILDER_SETUP.md)).

## References

- [Invoke prompt templates from Apex](https://developer.salesforce.com/blogs/2024/04/invoke-prompt-templates-from-flow-apex-or-the-rest-api)
- [ISSUE_DESCRIPTION_FOR_EXPERTS.md](../implementation/ISSUE_DESCRIPTION_FOR_EXPERTS.md) — only relevant if you enable Data Library grounding on a template (not used in the default no-grounding design)
