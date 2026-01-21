// Check if Models API is available
try {
    // Try to access the Models API namespace
    Type apiType = Type.forName('aiplatform', 'ModelsAPI');
    System.debug('Models API is available: ' + apiType);
} catch (Exception e) {
    System.debug('Models API not found: ' + e.getMessage());
}

// Check for Prompt object
try {
    List<Prompt> prompts = [SELECT Id, DeveloperName FROM Prompt LIMIT 1];
    System.debug('Prompt Builder is available. Found prompts: ' + prompts.size());
} catch (Exception e) {
    System.debug('Prompt Builder not available: ' + e.getMessage());
}
