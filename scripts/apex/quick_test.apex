// Quick test - will use mock responses automatically
Id testItemId = '0pdKY000000bmK0YAI'; // Manufactured Goods / Construction / Equipment

System.debug('=== Testing USEEIO Matching Service ===');
System.debug('Test Item ID: ' + testItemId);

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);

System.debug('Status: ' + result.status);
System.debug('Recommended NAICS: ' + result.recommendedNaicsCode);
System.debug('Confidence: ' + result.confidenceScore);
System.debug('Reasoning: ' + result.reasoning);
System.debug('Factor ID: ' + result.recommendedFactorId);
