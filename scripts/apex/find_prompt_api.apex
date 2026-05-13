// Find the correct way to call Prompt Builder templates
// Run in Developer Console

System.debug('=== Finding Prompt Builder API ===');

// Test 1: Check ConnectApi.EinsteinPromptTemplateGenerationsInput properties
try {
    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    
    // Try to see what properties exist using describe
    System.debug('Input object created');
    
    // Try setting properties one by one
    try {
        input.promptTemplateApiName = 'NAICS_Matching_Prompt';
        System.debug('✓ promptTemplateApiName works');
    } catch (Exception e) {
        System.debug('✗ promptTemplateApiName: ' + e.getMessage());
    }
    
    try {
        input.promptTemplate = 'NAICS_Matching_Prompt';
        System.debug('✓ promptTemplate works');
    } catch (Exception e) {
        System.debug('✗ promptTemplate: ' + e.getMessage());
    }
    
    try {
        input.templateApiName = 'NAICS_Matching_Prompt';
        System.debug('✓ templateApiName works');
    } catch (Exception e) {
        System.debug('✗ templateApiName: ' + e.getMessage());
    }
    
} catch (Exception e) {
    System.debug('Error creating input: ' + e.getMessage());
}

// Test 2: Check WrappedValue
try {
    ConnectApi.WrappedValue val = new ConnectApi.WrappedValue();
    val.value = 'test';
    System.debug('✓ WrappedValue.value works');
} catch (Exception e) {
    System.debug('✗ WrappedValue.value: ' + e.getMessage());
    // Try other properties
    try {
        ConnectApi.WrappedValue val2 = new ConnectApi.WrappedValue();
        val2.stringValue = 'test';
        System.debug('✓ WrappedValue.stringValue works');
    } catch (Exception e2) {
        System.debug('✗ WrappedValue.stringValue: ' + e2.getMessage());
    }
}

// Test 3: Check if there's a different API method
try {
    // Check what methods are available on EinsteinLLM
    System.debug('Checking EinsteinLLM methods...');
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
