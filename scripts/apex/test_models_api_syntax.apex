// Test script to find the correct Models API syntax for your org
// Run this in Developer Console: Debug → Open Execute Anonymous Window
// Copy and paste this entire script, then click Execute

System.debug('=== Testing Models API Syntax ===');

// Test 1: Check if ModelsAPI class exists
try {
    Type modelsAPIType = Type.forName('aiplatform', 'ModelsAPI');
    System.debug('✓ ModelsAPI class found: ' + modelsAPIType);
} catch (Exception e) {
    System.debug('✗ ModelsAPI class not found: ' + e.getMessage());
    return;
}

// Test 2: Try to create Request object (standard syntax)
try {
    aiplatform.ModelsAPI.Request request = new aiplatform.ModelsAPI.Request();
    System.debug('✓ Request class created successfully');
    
    // Test 3: Try setting promptTemplate property
    try {
        request.promptTemplate = 'NAICS_Matching_Prompt';
        System.debug('✓ promptTemplate property works');
    } catch (Exception e) {
        System.debug('✗ promptTemplate property error: ' + e.getMessage());
    }
    
    // Test 4: Try setting variables property
    try {
        Map<String, Object> testVars = new Map<String, Object>();
        testVars.put('category1', 'Test Category');
        request.variables = testVars;
        System.debug('✓ variables property works');
    } catch (Exception e) {
        System.debug('✗ variables property error: ' + e.getMessage());
    }
    
    // Test 5: Try invoking the API (this will fail if template doesn't exist, but syntax should work)
    try {
        aiplatform.ModelsAPI.Response response = aiplatform.ModelsAPI.invoke(request);
        System.debug('✓ invoke() method works!');
        if (response != null) {
            System.debug('✓ Response object created');
            if (response.text != null) {
                System.debug('✓ Response.text accessible: ' + response.text.substring(0, Math.min(100, response.text.length())));
            } else {
                System.debug('⚠ Response.text is null (template may not exist yet)');
            }
        }
    } catch (Exception e) {
        // This might fail if template doesn't exist, but check if it's a syntax error
        if (e.getMessage().contains('Invalid type') || e.getMessage().contains('Variable does not exist')) {
            System.debug('✗ Syntax error in invoke() call: ' + e.getMessage());
        } else {
            System.debug('⚠ invoke() syntax OK, but call failed (likely template not found): ' + e.getMessage());
        }
    }
    
} catch (TypeException e) {
    System.debug('✗ Request class syntax error: ' + e.getMessage());
    System.debug('  The API structure may be different in your org version.');
}

// Test 6: Try alternative syntax (if standard doesn't work)
System.debug('\n=== Trying Alternative Syntax ===');
try {
    // Some orgs might use different class names or structure
    // Try checking what's available
    Type requestType = Type.forName('aiplatform', 'ModelsAPI$Request');
    System.debug('✓ Nested Request class found: ' + requestType);
} catch (Exception e) {
    System.debug('✗ Nested Request class not found: ' + e.getMessage());
}

// Summary
System.debug('\n=== Summary ===');
System.debug('If you see ✓ marks above, the standard syntax should work.');
System.debug('If you see ✗ marks, you may need to check Salesforce documentation for your org version.');
System.debug('If invoke() failed but syntax is OK, create the Prompt Builder template first.');
