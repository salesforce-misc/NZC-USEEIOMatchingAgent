// Test script to find the correct Knowledge Grounding syntax
// Run this in Developer Console: Debug → Open Execute Anonymous Window

System.debug('=== Testing Knowledge Grounding Configuration ===');

try {
    // Create request structure
    aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
    request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    
    aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
    requestBody.prompt = 'Search the Knowledge Library (USEEIO_Reference) for information about NAICS code 423320. What is this industry?';
    
    // Test 1: Check if GenerationRequest has grounding property
    try {
        // Try to set grounding on requestBody
        // Note: This will fail if property doesn't exist, but we'll catch it
        System.debug('Testing: requestBody.grounding');
        // Uncomment to test:
        // requestBody.grounding = new aiplatform.ModelsAPI_Grounding();
        // requestBody.grounding.enabled = true;
        System.debug('✓ GenerationRequest has grounding property');
    } catch (Exception e) {
        System.debug('✗ GenerationRequest.grounding not available: ' + e.getMessage());
    }
    
    // Test 2: Check if request has grounding property
    try {
        System.debug('Testing: request.grounding');
        // Uncomment to test:
        // request.grounding = new aiplatform.ModelsAPI_Grounding();
        System.debug('✓ Request has grounding property');
    } catch (Exception e) {
        System.debug('✗ Request.grounding not available: ' + e.getMessage());
    }
    
    // Test 3: Check for alternative property names
    try {
        System.debug('Testing: requestBody.knowledgeSource');
        // Uncomment to test:
        // requestBody.knowledgeSource = 'USEEIO_Reference';
        System.debug('✓ GenerationRequest has knowledgeSource property');
    } catch (Exception e) {
        System.debug('✗ GenerationRequest.knowledgeSource not available');
    }
    
    // Test 4: Check what properties GenerationRequest actually has
    System.debug('\n=== Available Properties ===');
    System.debug('Request body type: ' + Type.forName('aiplatform', 'ModelsAPI_GenerationRequest'));
    
    // Make the request (without grounding first)
    request.body = requestBody;
    aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
    aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
    
    System.debug('\n=== Response Test ===');
    if (response != null && response.Code200 != null && response.Code200.generation != null) {
        String responseText = response.Code200.generation.generatedText;
        System.debug('Response received: ' + responseText.substring(0, Math.min(200, responseText.length())));
        
        // Check if response seems to use grounding
        if (responseText.contains('423320') || responseText.contains('NAICS') || responseText.contains('industry')) {
            System.debug('✓ Response appears to reference NAICS content - grounding may be working');
        } else {
            System.debug('⚠ Response may not be using grounding - check if explicit configuration is needed');
        }
    }
    
} catch (Exception e) {
    System.debug('Error during test: ' + e.getMessage());
    System.debug('Line: ' + e.getLineNumber());
}

System.debug('\n=== Next Steps ===');
System.debug('1. Check the debug output above for available properties');
System.debug('2. Try uncommenting the grounding tests one by one');
System.debug('3. Update LLMService.cls with the working syntax');
