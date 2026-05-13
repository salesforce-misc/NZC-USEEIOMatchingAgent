// Find the exact Models API syntax for this org
try {
    // Try to access the ModelsAPI class
    Type modelsAPIType = Type.forName('aiplatform', 'ModelsAPI');
    System.debug('ModelsAPI class found: ' + modelsAPIType);
    
    // Try to find Request class
    try {
        Type requestType = Type.forName('aiplatform', 'ModelsAPI$Request');
        System.debug('Request class found: ' + requestType);
    } catch (Exception e) {
        System.debug('Request class not found as nested: ' + e.getMessage());
        // Try as separate class
        try {
            Type requestType = Type.forName('aiplatform', 'Request');
            System.debug('Request class found as separate: ' + requestType);
        } catch (Exception e2) {
            System.debug('Request class not found: ' + e2.getMessage());
        }
    }
    
    // Try to find Response class
    try {
        Type responseType = Type.forName('aiplatform', 'ModelsAPI$Response');
        System.debug('Response class found: ' + responseType);
    } catch (Exception e) {
        System.debug('Response class not found as nested: ' + e2.getMessage());
        // Try as separate class
        try {
            Type responseType = Type.forName('aiplatform', 'Response');
            System.debug('Response class found as separate: ' + responseType);
        } catch (Exception e2) {
            System.debug('Response class not found: ' + e2.getMessage());
        }
    }
    
    // Try to find invoke method
    System.debug('Checking for invoke method...');
    
} catch (Exception e) {
    System.debug('Error accessing ModelsAPI: ' + e.getMessage());
}
