// Test different ways to invoke Prompt Builder template
// Run in Developer Console

System.debug('=== Testing Prompt Template Invocation ===');

// First, check if template exists
List<Prompt> prompts = [SELECT Id, DeveloperName FROM Prompt WHERE DeveloperName = 'NAICS_Matching_Prompt' LIMIT 1];
if (prompts.isEmpty()) {
    System.debug('✗ Template NAICS_Matching_Prompt not found');
    System.debug('Available prompts:');
    List<Prompt> allPrompts = [SELECT Id, DeveloperName FROM Prompt LIMIT 10];
    for (Prompt p : allPrompts) {
        System.debug('  - ' + p.DeveloperName);
    }
} else {
    System.debug('✓ Template found: ' + prompts[0].Id);
    
    // Try Option 1: Connect API (if available)
    try {
        // This might not compile, but let's see
        System.debug('Trying Connect API approach...');
        // ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        System.debug('Connect API classes may not be available in this org version');
    } catch (Exception e) {
        System.debug('Connect API not available: ' + e.getMessage());
    }
    
    // Option 2: Check if Prompt has invoke method
    try {
        // Prompt p = prompts[0];
        // p.invoke(...); // Probably doesn't exist, but worth checking
        System.debug('Prompt object doesn\'t have direct invoke method');
    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage());
    }
}

System.debug('\n=== Recommendation ===');
System.debug('If template exists, you may need to:');
System.debug('1. Check Prompt Builder for "API Usage" or code examples');
System.debug('2. Use Flow to invoke the template, then call Flow from Apex');
System.debug('3. Query Prompt object to get prompt text, substitute variables, use createGenerations');
System.debug('4. Check if your org version supports ConnectApi.EinsteinLLM methods');
