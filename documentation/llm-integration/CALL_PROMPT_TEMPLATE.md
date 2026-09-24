# Calling the NAICS Prompt Template from Apex

`LLMService.suggestNaicsCode` invokes the Flex template configured in **Custom Metadata** (`LLM_Config__mdt` record **Default**) using **`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`**.

**Design:** No Data Library grounding — the template uses **candidate codes + descriptions from Apex** and the model's **NAICS 2017 knowledge**, matching the original no-grounding design. **Cache hits** (`LLM_Response_Cache__c` / batch in-memory dedupe) are handled in Apex **before** this call is ever made.

## Configuration

All LLM invocation settings and scoring thresholds are stored in the `LLM_Config__mdt` Default record. See [CONFIGURATION_GUIDE.md](../operations/CONFIGURATION_GUIDE.md) for instructions on updating these values without a code redeployment.

| Setting | Field | Default | Purpose |
|---|---|---|---|
| Template API name | `Prompt_Template_API_Name__c` | `NAICS_Matching_Prompt` | Developer name of the Agentforce Prompt Builder Flex template |
| Application name | `Prompt_Invocation_Application_Name__c` | `PromptBuilderPreview` | `EinsteinLlmAdditionalConfigInput.applicationName`. If invocation fails with an authorization error, try `PromptTemplateGenerationsInvocable` — the correct value varies by org. |
| Auto-apply threshold | `Auto_Apply_Threshold__c` | `0.7` | Composite confidence score at or above which a match is auto-applied |
| LLM weight | `LLM_Weight__c` | `0.6` | Weight of the LLM confidence signal in the composite score |
| Match count weight | `Match_Count_Weight__c` | `0.2` | Weight of the factor set match count in the composite score |
| Factor set weight | `Factor_Set_Weight__c` | `0.2` | Weight of factor set validation in the composite score |
| LLM score HIGH | `LLM_Score_High__c` | `0.9` | Raw score assigned when the LLM returns `HIGH` confidence |
| LLM score MEDIUM | `LLM_Score_Medium__c` | `0.6` | Raw score assigned when the LLM returns `MEDIUM` confidence |
| LLM score LOW | `LLM_Score_Low__c` | `0.3` | Raw score assigned when the LLM returns `LOW` confidence |

## Apex Invocation Pattern

```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
promptInput.isPreview = false;
promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
promptInput.additionalConfig.numGenerations = 1;
promptInput.inputParams = new Map<String, ConnectApi.WrappedValue>{
    'Input:category1'             => wrap('...'),
    'Input:category2'             => wrap('...'),
    'Input:category3'             => wrap('...'),
    'Input:candidateCodes'        => wrap('541211, 541219'),
    'Input:candidateDescriptions' => wrap('- 541211: ...')
};

ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        'NAICS_Matching_Prompt',
        promptInput
    );

String jsonText = result.generations[0].text;
```

The `Input:*` keys **must match** the Flex template input variable API names in Prompt Builder exactly — including case. If a variable name is renamed in Prompt Builder without updating the Apex map, the template receives a null value for that input and will produce a degraded or incorrect response.

## Expected Response Schema

The template is instructed to return a JSON object with this structure:

```json
{
  "suggestedNaicsCode": "6-digit code or null",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Concise justification using NAICS 2017 semantics",
  "alternativeNaicsCodes": ["code1", "code2"],
  "uncertaintyFactors": ["factor1", "factor2"]
}
```

`LLMService.parseLLMResponse()` validates the returned code against a 6-digit numeric regex. Markdown-fenced responses (where the model wraps the JSON in `` ```json `` blocks) are handled by stripping the fence before parsing.

## Candidate Constraint

The system prompt in `NAICS_Matching_Prompt` includes a non-negotiable instruction:

> If the candidate list is not empty and not 'None provided', you MUST pick `suggestedNaicsCode` from that list only. Do not invent or substitute a different 6-digit code outside the list.

This constraint ensures every suggested code is resolvable in the customer's emissions factor set. If you modify the prompt template, preserve this instruction. Without it, the model may return a valid-format code that does not exist in `PcmtEmssnFctrSetItem`, and `findMatchingFactors()` will silently return an empty result.

## Agentforce Flex Credits

Each call to `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` consumes Agentforce Flex Credits. The response cache and in-memory deduplication in `BulkMatchingBatch` are specifically designed to minimize the number of live calls made. Confirm Flex Credits are provisioned in the org before running bulk matching in production.

## References

- [Invoke prompt templates from Apex](https://developer.salesforce.com/blogs/2024/04/invoke-prompt-templates-from-flow-apex-or-the-rest-api)
- [ConnectApi.EinsteinLLM Documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_connectapi_EinsteinLLM.htm)
