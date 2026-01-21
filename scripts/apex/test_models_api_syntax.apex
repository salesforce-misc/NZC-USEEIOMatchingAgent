// Test different Models API syntaxes to find the correct one
try {
    // Try option 1: Direct class instantiation
    aiplatform.ModelsAPI.Request req1 = new aiplatform.ModelsAPI.Request();
    System.debug('Option 1 works: Request class exists');
    
    // Try to set properties
    req1.model = 'gpt-4o';
    req1.prompt = 'Test prompt';
    System.debug('Option 1: Properties set successfully');
    
    // Try to invoke
    aiplatform.ModelsAPI.Response res1 = aiplatform.ModelsAPI.invoke(req1);
    System.debug('Option 1: Invoke successful');
    
} catch (Exception e) {
    System.debug('Option 1 failed: ' + e.getMessage() + ' at line ' + e.getLineNumber());
}
