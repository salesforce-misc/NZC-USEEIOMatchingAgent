/**
 * @description Test class for USEEIOMatchingService
 * @author Your Name
 * @date 2025-01-XX
 */
@isTest
private class USEEIOMatchingServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create test data hierarchy:
        // Scope3PcmtSummary -> PcmtEmssnFctrSet -> PcmtEmssnFctrSetItem
        
        // Create Procurement Emissions Factor Set
        PcmtEmssnFctrSet testFactorSet = new PcmtEmssnFctrSet(
            Name = 'Test Factor Set'
        );
        insert testFactorSet;
        
        // Create Scope3PcmtSummary
        Scope3PcmtSummary testSummary = new Scope3PcmtSummary(
            CalendarYear = '2024',
            PcmtEmssnFctrId = testFactorSet.Id
        );
        insert testSummary;
        
        // Create test PcmtEmssnFctrSetItem records
        List<PcmtEmssnFctrSetItem> testFactors = new List<PcmtEmssnFctrSetItem>();
        
        // Accounting services
        testFactors.add(new PcmtEmssnFctrSetItem(
            PcmtEmssnFctrSetId = testFactorSet.Id,
            EconomicSectorCode = '541211',
            EconomicSector = 'Accounting Services',
            EconomicSectorCategory = 'Professional Services',
            TotScpe3EmssnPerMillionSpent = 125.5
        ));
        
        // IT consulting
        testFactors.add(new PcmtEmssnFctrSetItem(
            PcmtEmssnFctrSetId = testFactorSet.Id,
            EconomicSectorCode = '541511',
            EconomicSector = 'Custom Computer Programming Services',
            EconomicSectorCategory = 'IT Services',
            TotScpe3EmssnPerMillionSpent = 98.3
        ));
        
        // Office supplies
        testFactors.add(new PcmtEmssnFctrSetItem(
            PcmtEmssnFctrSetId = testFactorSet.Id,
            EconomicSectorCode = '453210',
            EconomicSector = 'Office Supplies and Stationery Stores',
            EconomicSectorCategory = 'Retail',
            TotScpe3EmssnPerMillionSpent = 145.2
        ));
        
        insert testFactors;
        
        // Create test Scope3PcmtItem
        Scope3PcmtItem testItem = new Scope3PcmtItem(
            ProcurementSummaryId = testSummary.Id,
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
        // Create item without ProcurementSummaryId
        Scope3PcmtItem testItem = new Scope3PcmtItem(
            SpendingCategory1 = 'Test Category',
            SpentAmount = 1000,
            SpentDate = Date.today()
        );
        insert testItem;
        
        Test.startTest();
        MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItem.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('NO_MATCH', result.status, 'Should return NO_MATCH');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
    }
    
    @isTest
    static void testMatchSpendItemToFactor_NoSpendingCategories() {
        Scope3PcmtSummary testSummary = [SELECT Id FROM Scope3PcmtSummary LIMIT 1];
        
        Scope3PcmtItem testItem = new Scope3PcmtItem(
            ProcurementSummaryId = testSummary.Id,
            SpentAmount = 1000,
            SpentDate = Date.today()
        );
        insert testItem;
        
        Test.startTest();
        MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItem.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('NO_MATCH', result.status, 'Should return NO_MATCH');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        System.assert(score < 0.5, 'Low confidence should result in score < 0.5');
    }
    
    @isTest
    static void testCalculateConfidenceScore_MultipleMatches() {
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        System.assert(score < 0.5, 'No matches should result in lower score');
    }
    
    @isTest
    static void testApplyMatch_Success() {
        Scope3PcmtItem testItem = [SELECT Id FROM Scope3PcmtItem LIMIT 1];
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
        Scope3PcmtSummary testSummary = [SELECT PcmtEmssnFctrId FROM Scope3PcmtSummary LIMIT 1];
        Id factorSetId = testSummary.PcmtEmssnFctrId;
        
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
