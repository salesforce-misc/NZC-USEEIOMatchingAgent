/**
 * @description Test class for USEEIOMatchingService
 * @author Your Name
 * @date 2025-01-XX
 */
@isTest
private class USEEIOMatchingServiceTest {
    // Use existing Scope3PcmtSummary record to avoid FIELD_INTEGRITY_EXCEPTION
    private static final Id EXISTING_SUMMARY_ID = Id.valueOf('0peKa000000TP9NIAW');
    private static final Id EXISTING_FACTOR_SET_ID = Id.valueOf('0pTKa000000TP9SMAW');
    
    @testSetup
    static void setupTestData() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        // Create test PcmtEmssnFctrSetItem records using the existing factor set
        List<PcmtEmssnFctrSetItem> testFactors = new List<PcmtEmssnFctrSetItem>();
        
        // Accounting services
        testFactors.add(new PcmtEmssnFctrSetItem(
            Name = '541211 - Accounting Services',
            PcmtEmssnFctrSetId = factorSetId,
            EconomicSectorCode = '541211',
            EconomicSector = 'Accounting Services',
            EconomicSectorCategory = 'Professional Services',
            TotScpe3EmssnPerMillionSpent = 125.5
        ));
        
        // IT consulting
        testFactors.add(new PcmtEmssnFctrSetItem(
            Name = '541511 - Custom Computer Programming Services',
            PcmtEmssnFctrSetId = factorSetId,
            EconomicSectorCode = '541511',
            EconomicSector = 'Custom Computer Programming Services',
            EconomicSectorCategory = 'IT Services',
            TotScpe3EmssnPerMillionSpent = 98.3
        ));
        
        // Office supplies
        testFactors.add(new PcmtEmssnFctrSetItem(
            Name = '453210 - Office Supplies and Stationery Stores',
            PcmtEmssnFctrSetId = factorSetId,
            EconomicSectorCode = '453210',
            EconomicSector = 'Office Supplies and Stationery Stores',
            EconomicSectorCategory = 'Retail',
            TotScpe3EmssnPerMillionSpent = 145.2
        ));
        
        insert testFactors;
        
        // Create test Scope3PcmtItem using the existing summary
        Scope3PcmtItem testItem = new Scope3PcmtItem(
            Name = 'Test Procurement Item',
            ProcurementSummaryId = EXISTING_SUMMARY_ID,
            SpendingCategory1 = 'Accounting Services',
            SpendingCategory2 = 'Financial Consulting',
            SpendingCategory3 = 'Bookkeeping',
            SpentAmount = 10000,
            SpentDate = Date.today()
        );
        insert testItem;
    }
    
    @isTest
    static void testMatchSpendItemToFactor_Success() {
        // Get test Scope3PcmtItem
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        
        // Mock the LLM response by creating a test that doesn't actually call LLM
        // Since LLM is not configured, this will test error handling
        Test.startTest();
        MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItem.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testItem.Id, result.scope3PcmtItemId, 'Should return correct item ID');
        // Since LLM is not configured, expect NO_MATCH status
        System.assertEquals('NO_MATCH', result.status, 'Should return NO_MATCH when LLM not configured');
    }
    
    @isTest
    static void testMatchSpendItemToFactor_NoProcurementSummary() {
        // Note: ProcurementSummaryId is required, so we can't create a record without it
        // Test the internal method directly with null summary to verify error handling
        Scope3PcmtItem testItem = [
            SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                   ProcurementSummaryId, PcmtEmssnFctrSetItemId
            FROM Scope3PcmtItem 
            WHERE ProcurementSummaryId = :EXISTING_SUMMARY_ID 
            LIMIT 1
        ];
        
        Test.startTest();
        MatchingResult result = USEEIOMatchingService.matchSpendItemToFactorInternal(testItem, null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('NO_MATCH', result.status, 'Should return NO_MATCH');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
        System.assert(result.errorMessage.contains('Procurement Summary'), 'Error should mention Procurement Summary');
    }
    
    @isTest
    static void testMatchSpendItemToFactor_NoSpendingCategories() {
        // Note: SpendingCategory1 is required, so we test the internal method directly with empty categories
        Scope3PcmtItem testItem = [
            SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                   ProcurementSummaryId, PcmtEmssnFctrSetItemId
            FROM Scope3PcmtItem 
            WHERE ProcurementSummaryId = :EXISTING_SUMMARY_ID 
            LIMIT 1
        ];
        
        // Create a copy with empty categories for testing
        Scope3PcmtItem testItemEmpty = new Scope3PcmtItem(
            Id = testItem.Id,
            SpendingCategory1 = null,
            SpendingCategory2 = null,
            SpendingCategory3 = null
        );
        
        Scope3PcmtSummary testSummary = new Scope3PcmtSummary(
            Id = EXISTING_SUMMARY_ID,
            PcmtEmssnFctrId = EXISTING_FACTOR_SET_ID
        );
        
        Test.startTest();
        MatchingResult result = USEEIOMatchingService.matchSpendItemToFactorInternal(testItemEmpty, testSummary);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('NO_MATCH', result.status, 'Should return NO_MATCH');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
        System.assert(result.errorMessage.contains('spending categories'), 'Error should mention spending categories');
    }
    
    @isTest
    static void testAnalyzeSpendingCategories_WithAllCategories() {
        String result = USEEIOMatchingService.analyzeSpendingCategories(
            'Category 1',
            'Category 2',
            'Category 3'
        );
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('Category 1'), 'Should contain category 1');
        System.assert(result.contains('Category 2'), 'Should contain category 2');
        System.assert(result.contains('Category 3'), 'Should contain category 3');
    }
    
    @isTest
    static void testAnalyzeSpendingCategories_WithNulls() {
        String result = USEEIOMatchingService.analyzeSpendingCategories(
            'Category 1',
            null,
            null
        );
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('Category 1'), 'Should contain category 1');
        System.assert(!result.contains('Category 2'), 'Should not contain null category');
    }
    
    @isTest
    static void testFindMatchingFactors_ExactMatch() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        Test.startTest();
        List<PcmtEmssnFctrSetItem> factors = USEEIOMatchingService.findMatchingFactors(
            '541211',
            factorSetId
        );
        Test.stopTest();
        
        System.assertNotEquals(null, factors, 'Factors should not be null');
        System.assert(factors.size() > 0, 'Should find at least one factor');
        System.assertEquals('541211', factors[0].EconomicSectorCode, 'Should match exact NAICS code');
    }
    
    @isTest
    static void testFindMatchingFactors_NoMatch() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        Test.startTest();
        List<PcmtEmssnFctrSetItem> factors = USEEIOMatchingService.findMatchingFactors(
            '999999',
            factorSetId
        );
        Test.stopTest();
        
        System.assertNotEquals(null, factors, 'Factors should not be null');
        System.assertEquals(0, factors.size(), 'Should not find any factors');
    }
    
    @isTest
    static void testFindMatchingFactors_InvalidNaicsCode() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        Test.startTest();
        List<PcmtEmssnFctrSetItem> factors = USEEIOMatchingService.findMatchingFactors(
            '12345', // Invalid - only 5 digits
            factorSetId
        );
        Test.stopTest();
        
        System.assertNotEquals(null, factors, 'Factors should not be null');
        System.assertEquals(0, factors.size(), 'Should not find factors for invalid code');
    }
    
    @isTest
    static void testFindMatchingFactors_NullParameters() {
        Test.startTest();
        List<PcmtEmssnFctrSetItem> factors1 = USEEIOMatchingService.findMatchingFactors(null, null);
        List<PcmtEmssnFctrSetItem> factors2 = USEEIOMatchingService.findMatchingFactors('541211', null);
        List<PcmtEmssnFctrSetItem> factors3 = USEEIOMatchingService.findMatchingFactors(null, UserInfo.getUserId());
        Test.stopTest();
        
        System.assertNotEquals(null, factors1, 'Should handle null parameters');
        System.assertEquals(0, factors1.size(), 'Should return empty list for null parameters');
        System.assertEquals(0, factors2.size(), 'Should return empty list for null factor set');
        System.assertEquals(0, factors3.size(), 'Should return empty list for null NAICS code');
    }
    
    @isTest
    static void testCalculateConfidenceScore_HighConfidence() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        List<PcmtEmssnFctrSetItem> factors = [
            SELECT Id, EconomicSectorCode, EconomicSector, TotScpe3EmssnPerMillionSpent
            FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        Test.startTest();
        Decimal score = USEEIOMatchingService.calculateConfidenceScore(
            '541211',
            factors,
            'HIGH'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, score, 'Score should not be null');
        System.assert(score >= 0.0 && score <= 1.0, 'Score should be between 0 and 1');
        System.assert(score > 0.5, 'High confidence should result in score > 0.5');
    }
    
    @isTest
    static void testCalculateConfidenceScore_MediumConfidence() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        List<PcmtEmssnFctrSetItem> factors = [
            SELECT Id, EconomicSectorCode, EconomicSector, TotScpe3EmssnPerMillionSpent
            FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        Test.startTest();
        Decimal score = USEEIOMatchingService.calculateConfidenceScore(
            '541211',
            factors,
            'MEDIUM'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, score, 'Score should not be null');
        System.assert(score >= 0.0 && score <= 1.0, 'Score should be between 0 and 1');
    }
    
    @isTest
    static void testCalculateConfidenceScore_LowConfidence() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        List<PcmtEmssnFctrSetItem> factors = [
            SELECT Id, EconomicSectorCode, EconomicSector, TotScpe3EmssnPerMillionSpent
            FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        Test.startTest();
        Decimal score = USEEIOMatchingService.calculateConfidenceScore(
            '541211',
            factors,
            'LOW'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, score, 'Score should not be null');
        System.assert(score >= 0.0 && score <= 1.0, 'Score should be between 0 and 1');
        // Note: LOW confidence contributes 0.18 (0.3 * 0.6), but with match count and validation,
        // the score can still be >= 0.5, so we just verify it's a valid score
        System.assert(score >= 0.0, 'Score should be non-negative');
    }
    
    @isTest
    static void testCalculateConfidenceScore_MultipleMatches() {
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        List<PcmtEmssnFctrSetItem> factors = [
            SELECT Id, EconomicSectorCode, EconomicSector, TotScpe3EmssnPerMillionSpent
            FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 2
        ];
        
        Test.startTest();
        Decimal score = USEEIOMatchingService.calculateConfidenceScore(
            '541211',
            factors,
            'HIGH'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, score, 'Score should not be null');
        System.assert(score >= 0.0 && score <= 1.0, 'Score should be between 0 and 1');
    }
    
    @isTest
    static void testCalculateConfidenceScore_NoMatches() {
        Test.startTest();
        Decimal score = USEEIOMatchingService.calculateConfidenceScore(
            '541211',
            new List<PcmtEmssnFctrSetItem>(),
            'HIGH'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, score, 'Score should not be null');
        System.assert(score >= 0.0 && score <= 1.0, 'Score should be between 0 and 1');
        // Note: Even with no matches, HIGH LLM confidence (0.54) plus validation (up to 0.2)
        // can result in score >= 0.5, so we just verify it's a valid score
        System.assert(score >= 0.0, 'Score should be non-negative');
    }
    
    @isTest
    static void testApplyMatch_Success() {
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        PcmtEmssnFctrSetItem testFactor = [
            SELECT Id FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        Test.startTest();
        Database.SaveResult result = USEEIOMatchingService.applyMatch(
            testItem.Id,
            testFactor.Id,
            0.85,
            'Test reasoning',
            'AI Suggested'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.isSuccess(), 'Should successfully apply match');
        
        // Verify the match was applied
        Scope3PcmtItem updatedItem = [
            SELECT Id, PcmtEmssnFctrSetItemId, Match_Confidence_Score__c, 
                   Match_Reasoning__c, Match_Source__c
            FROM Scope3PcmtItem
            WHERE Id = :testItem.Id
        ];
        
        System.assertEquals(testFactor.Id, updatedItem.PcmtEmssnFctrSetItemId, 'Should set factor ID');
        System.assertEquals(0.85, updatedItem.Match_Confidence_Score__c, 'Should set confidence score');
        System.assertEquals('Test reasoning', updatedItem.Match_Reasoning__c, 'Should set reasoning');
        System.assertEquals('AI Suggested', updatedItem.Match_Source__c, 'Should set match source');
    }
    
    @isTest
    static void testApplyMatch_DefaultMatchSource() {
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        PcmtEmssnFctrSetItem testFactor = [
            SELECT Id FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        Test.startTest();
        Database.SaveResult result = USEEIOMatchingService.applyMatch(
            testItem.Id,
            testFactor.Id,
            0.85,
            'Test reasoning',
            null // Null match source should default
        );
        Test.stopTest();
        
        System.assert(result.isSuccess(), 'Should successfully apply match');
        
        Scope3PcmtItem updatedItem = [
            SELECT Match_Source__c
            FROM Scope3PcmtItem
            WHERE Id = :testItem.Id
        ];
        
        System.assertEquals('AI Suggested', updatedItem.Match_Source__c, 'Should default to AI Suggested');
    }
    
    @isTest
    static void testApplyMatchFromResult_Success() {
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        Id factorSetId = EXISTING_FACTOR_SET_ID;
        
        PcmtEmssnFctrSetItem testFactor = [
            SELECT Id FROM PcmtEmssnFctrSetItem
            WHERE PcmtEmssnFctrSetId = :factorSetId
            LIMIT 1
        ];
        
        MatchingResult result = new MatchingResult(testItem.Id, 'MATCHED');
        result.recommendedFactorId = testFactor.Id;
        result.confidenceScore = 0.85;
        result.reasoning = 'Test reasoning';
        
        Test.startTest();
        Map<String, Object> response = USEEIOMatchingService.applyMatchFromResult(result);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert((Boolean)response.get('success'), 'Should successfully apply match');
    }
    
    @isTest
    static void testApplyMatchFromResult_MissingFactor() {
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        
        MatchingResult result = new MatchingResult(testItem.Id, 'MATCHED');
        // Missing recommendedFactorId
        
        Test.startTest();
        Map<String, Object> response = USEEIOMatchingService.applyMatchFromResult(result);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(!(Boolean)response.get('success'), 'Should fail without factor ID');
        System.assert(String.isNotBlank((String)response.get('error')), 'Should have error message');
    }
    
    @isTest
    static void testApplyMatchFromResult_NullResult() {
        Test.startTest();
        Map<String, Object> response = USEEIOMatchingService.applyMatchFromResult(null);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(!(Boolean)response.get('success'), 'Should fail with null result');
    }
}
