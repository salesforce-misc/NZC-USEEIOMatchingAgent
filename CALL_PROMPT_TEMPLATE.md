# How to Call Prompt Builder Template from Apex
## Finding the Correct API Method

## The Challenge

The `createGenerations` API doesn't directly support calling Prompt Builder templates. We need to find the correct Connect API method.

## Option 1: Use ConnectApi.EinsteinLLM (Recommended)

Based on Salesforce documentation, use the Connect API:

```apex
// Query the template first
List<Prompt> prompts = [SELECT Id, DeveloperName FROM Prompt WHERE DeveloperName = 'NAICS_Matching_Prompt' LIMIT 1];

// Use Connect API
ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
// Set template reference (exact property name may vary)
input.promptTemplateApiName = 'NAICS_Matching_Prompt'; // or input.promptTemplate

// Set variables
Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
ConnectApi.WrappedValue val = new ConnectApi.WrappedValue();
val.value = 'test'; // or val.stringValue
inputParams.put('category1', val);
input.inputParams = inputParams;

// Call
ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = 
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(Network.getNetworkId(), input);
```

## Option 2: Query Prompt and Use Its Structure

If Connect API doesn't work, we can:

1. Query the Prompt object to get its prompt text
2. Substitute variables manually
3. Use createGenerations with the substituted prompt
4. But this loses the template's Knowledge Grounding configuration

## Next Steps

1. **Test in Developer Console** - Try the Connect API syntax above
2. **Check property names** - The exact property names may differ
3. **Verify response structure** - Check how to extract the generated text

## Current Code Status

The code currently:
- Queries the Prompt to verify it exists
- Uses createGenerations with a prompt that references the template name
- This won't actually invoke the template - it's just text

We need to find the correct API method to actually invoke the template.
