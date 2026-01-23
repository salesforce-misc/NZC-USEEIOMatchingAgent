# Issue Description for Salesforce Experts

## Problem Summary
I have a custom prompt template with a retriever that searches a grounding PDF in an Agentforce Data Library. The template works perfectly in Prompt Builder UI, but fails when called from Apex via Connect API with a retriever resolution error.

## Architecture
- **LWC Component** → Pulls field values from a record
- **Apex Class** → Calls Prompt Builder template via Connect API
- **Prompt Builder Template** → Uses retriever to search Data Library PDF
- **Data Library** → Contains NAICS 2017 Definition File PDF (fully indexed)

## What Works
✅ Prompt Builder UI test/preview works perfectly
✅ Retriever successfully finds relevant content from PDF
✅ Template is Active/Published (not Draft)
✅ All input variables are configured as free text inputs
✅ Data Library is fully indexed and accessible
✅ Input variables are correctly passed from Apex

## What Fails
❌ Calling template from Apex via Connect API fails
❌ Error: Retriever cannot be resolved by Connect API

## Technical Details

### Apex Code
```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = 
    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
promptInput.isPreview = false;

Map<String, ConnectApi.WrappedValue> inputValues = new Map<String, ConnectApi.WrappedValue>();
// ... setting input values ...

promptInput.inputParams = inputValues;
promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
promptInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result = 
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('NAICS_Matching_Prompt', promptInput);
```

### Error Message
```
ConnectApi.ConnectApiException: Error occurs resolving a data provider: 
EinsteinSearch:File_ADL_USEEIO_Referenc_1Cx_vOI485c3618. 
The data provider is either invalid or no longer exists.
```

### Retriever Details
- **Type**: Standard search index retriever (auto-generated when Data Library was set up)
- **Reference Name**: `EinsteinSearch:File_ADL_USEEIO_Referenc_1Cx_vOI485c3618`
- **Data Library**: `USEEIO_Reference` (API name)
- **Status**: Fully indexed and accessible
- **Behavior**: Retriever ID persists even after deleting and recreating template

### Template Configuration
- **Developer Name**: `NAICS_Matching_Prompt`
- **Status**: Active/Published
- **Type**: Flex template (`einstein_gpt__flex`)
- **Model**: `sfdc_ai__DefaultOpenAIGPT4OmniMini`
- **Retriever**: Configured in template with search parameters
- **Input Variables**: category1, category2, category3, candidateCodes (all String, required/optional as appropriate)

### Environment
- **API Version**: 65.0
- **Salesforce Edition**: (Please specify if known)
- **Agentforce**: Enabled
- **Data Library**: Fully indexed

## Attempted Solutions
1. ✅ Verified template is Active (not Draft)
2. ✅ Verified Developer Name matches exactly (case-sensitive)
3. ✅ Deleted and recreated template completely - same retriever ID appears
4. ✅ Removed and re-added retriever in Prompt Builder - same ID
5. ✅ Verified Data Library is fully indexed
6. ✅ Tested with different input values
7. ✅ Verified input variables are correctly defined in template
8. ❌ Tried deploying template metadata vs managing in UI - same issue
9. ❌ Checked for permissions issues - user has full access

## Key Questions
1. Why does the retriever work in Prompt Builder UI but not via Connect API?
2. Is there a permissions/access difference between UI and API?
3. Is the retriever ID format correct for API access?
4. Are there any known limitations with retrievers in Connect API?
5. Is there a way to make the retriever accessible via Apex?
6. Are there alternative architectural approaches to achieve grounding from Apex?

## Alternative Approaches Considered
- Using Models API directly (works but no grounding support)
- Using Flow to invoke template (not tested yet)
- Querying Data Library directly from Apex (not sure if possible)

## Additional Context
The retriever ID `File_ADL_USEEIO_Referenc_1Cx_vOI485c3618` appears to be stable and tied to the Data Library name. Even after completely deleting and recreating the template, the same retriever ID is used. This suggests the ID is derived from the Data Library configuration rather than being randomly generated.
