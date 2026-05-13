// Test Connect API for Prompt Builder templates
// Run this in Developer Console

System.debug('=== Testing Connect API for Prompt Builder ===');

try {
    // Test 1: Check EinsteinPromptTemplateGenerationsInput
    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    System.debug('✓ EinsteinPromptTemplateGenerationsInput created');
    
    // Test 2: Check available properties
    // Try different property names
    try {
        input.promptTemplateApiName = 'NAICS_Matching_Prompt';
        System.debug('✓ promptTemplateApiName property works');
    } catch (Exception e) {
        System.debug('✗ promptTemplateApiName: ' + e.getMessage());
        // Try alternatives
        try {
            input.promptTemplate = 'NAICS_Matching_Prompt';
            System.debug('✓ promptTemplate property works');
        } catch (Exception e2) {
            System.debug('✗ promptTemplate: ' + e2.getMessage());
        }
    }
    
    // Test 3: Check WrappedValue constructor
    try {
        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = 'test';
        System.debug('✓ WrappedValue created with .value property');
    } catch (Exception e) {
        System.debug('✗ WrappedValue: ' + e.getMessage());
    }
    
    // Test 4: Check inputParams
    try {
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        ConnectApi.WrappedValue val = new ConnectApi.WrappedValue();
        val.value = 'test';
        inputParams.put('category1', val);
        input.inputParams = inputParams;
        System.debug('✓ inputParams set successfully');
    } catch (Exception e) {
        System.debug('✗ inputParams: ' + e.getMessage());
    }
    
    // Test 5: Try calling the API
    try {
        Id networkId = Network.getNetworkId();
        if (networkId == null) {
            networkId = UserInfo.getOrganizationId(); // Fallback
        }
        
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = 
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(networkId, input);
        
        System.debug('✓ API call successful');
        if (response != null) {
            System.debug('Response type: ' + response);
            // Check response structure
            if (response.generations != null) {
                System.debug('✓ Generations found: ' + response.generations.size());
            }
        }
    } catch (Exception e) {
        System.debug('✗ API call failed: ' + e.getMessage());
        System.debug('Line: ' + e.getLineNumber());
    }
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
