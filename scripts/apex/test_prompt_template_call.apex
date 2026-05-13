// Test how to call a Prompt Builder template with createGenerations API
// Run this in Developer Console

System.debug('=== Testing Prompt Builder Template Call ===');

try {
    // Test 1: Check if we can reference template by name in prompt
    aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
    request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    
    aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
    
    // Option 1: Try referencing template in prompt
    requestBody.prompt = 'Use the Prompt Builder template "NAICS_Matching_Prompt" with variables: category1=test, category2=test2';
    
    request.body = requestBody;
    aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
    aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
    
    System.debug('Option 1 response: ' + response.Code200.generation.generatedText);
    
} catch (Exception e) {
    System.debug('Option 1 failed: ' + e.getMessage());
}

// Test 2: Check if GenerationRequest has a template property
try {
    aiplatform.ModelsAPI_GenerationRequest req = new aiplatform.ModelsAPI_GenerationRequest();
    
    // Try to see what properties exist
    // Common names: promptTemplate, template, templateName, promptId
    System.debug('Testing template properties...');
    
    // Uncomment to test:
    // req.promptTemplate = 'NAICS_Matching_Prompt';
    // or
    // req.template = 'NAICS_Matching_Prompt';
    // or
    // req.templateName = 'NAICS_Matching_Prompt';
    
} catch (Exception e) {
    System.debug('Template property test: ' + e.getMessage());
}

// Test 3: Check if we need to query the Prompt object first
try {
    List<Prompt> prompts = [SELECT Id, DeveloperName FROM Prompt WHERE DeveloperName = 'NAICS_Matching_Prompt' LIMIT 1];
    if (!prompts.isEmpty()) {
        System.debug('✓ Template found: ' + prompts[0].Id + ' - ' + prompts[0].DeveloperName);
        System.debug('Template ID: ' + prompts[0].Id);
    } else {
        System.debug('✗ Template not found');
    }
} catch (Exception e) {
    System.debug('Prompt query failed: ' + e.getMessage());
}
