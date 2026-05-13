// Test script for USEEIO Matching Service
// This will use mock responses since Data Library is still indexing

// Test with a real Scope3PcmtItem
Id testItemId = '0pdKY000000bmK0YAI'; // Manufactured Goods / Construction / Equipment

System.debug('=== Testing USEEIO Matching Service ===');
System.debug('Test Item ID: ' + testItemId);

// Query the item first to see what we're working with
Scope3PcmtItem item = [
    SELECT Id, Name, SpendingCategory1, SpendingCategory2, SpendingCategory3, 
           ProcurementSummaryId, PcmtEmssnFctrSetItemId
    FROM Scope3PcmtItem
    WHERE Id = :testItemId
    LIMIT 1
];

System.debug('Item Name: ' + item.Name);
System.debug('Category 1: ' + item.SpendingCategory1);
System.debug('Category 2: ' + item.SpendingCategory2);
System.debug('Category 3: ' + item.SpendingCategory3);
System.debug('Current Factor: ' + item.PcmtEmssnFctrSetItemId);

// Run the matching service
System.debug('\n=== Running Matching Service ===');
MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);

// Display results
System.debug('\n=== Matching Results ===');
System.debug('Status: ' + result.status);
System.debug('Recommended NAICS Code: ' + result.recommendedNaicsCode);
System.debug('Recommended Economic Sector: ' + result.recommendedEconomicSector);
System.debug('Recommended Factor ID: ' + result.recommendedFactorId);
System.debug('Confidence Score: ' + result.confidenceScore);
System.debug('Reasoning: ' + result.reasoning);
System.debug('Error Message: ' + result.errorMessage);

if (result.alternatives != null && result.alternatives.size() > 0) {
    System.debug('\n=== Alternative Matches ===');
    for (AlternativeMatch alt : result.alternatives) {
        System.debug('Alternative: ' + alt.naicsCode + ' (' + alt.economicSector + ') - Confidence: ' + alt.confidenceScore);
    }
}

// If we got a match, we could apply it (commented out for safety)
if (result.status == 'MATCHED' && result.recommendedFactorId != null) {
    System.debug('\n=== Ready to Apply Match ===');
    System.debug('To apply this match, run:');
    System.debug('USEEIOMatchingService.applyMatchFromResult(result);');
    // Uncomment the line below to actually apply the match:
    // Map<String, Object> applyResult = USEEIOMatchingService.applyMatchFromResult(result);
    // System.debug('Apply Result: ' + JSON.serialize(applyResult));
}

System.debug('\n=== Test Complete ===');
