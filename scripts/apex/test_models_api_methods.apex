// Check what methods are available on ModelsAPI
try {
    Type apiType = Type.forName('aiplatform', 'ModelsAPI');
    System.debug('ModelsAPI type: ' + apiType);
    
    // Try to get methods
    // Note: This is just to verify the class exists
    System.debug('ModelsAPI class is accessible');
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
