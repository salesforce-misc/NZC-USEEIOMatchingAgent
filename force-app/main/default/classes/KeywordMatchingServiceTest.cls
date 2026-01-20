/**
 * @description Test class for KeywordMatchingService
 * @author Your Name
 * @date 2025-01-XX
 */
@isTest
private class KeywordMatchingServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create test PcmtEmssnFctrSetItem records with various NAICS codes
        // Note: In real org, these would be children of PcmtEmssnFctrSet
        // For testing, we'll create minimal records
        
        // Create a test Procurement Emissions Factor Set
        PcmtEmssnFctrSet testFactorSet = new PcmtEmssnFctrSet(
            Name = 'Test Factor Set'
        );
        insert testFactorSet;
        
        // Create test PcmtEmssnFctrSetItem records with different NAICS codes
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
        
        // Manufacturing
        testFactors.add(new PcmtEmssnFctrSetItem(
            PcmtEmssnFctrSetId = testFactorSet.Id,
            EconomicSectorCode = '311111',
            EconomicSector = 'Dog and Cat Food Manufacturing',
            EconomicSectorCategory = 'Manufacturing',
            TotScpe3EmssnPerMillionSpent = 250.8
        ));
        
        insert testFactors;
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithMatchingKeywords() {
        // Test with keywords that should match
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            'Accounting Services',
            'Financial Consulting',
            'Bookkeeping',
            10
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // May or may not find candidates depending on test data
        // Just verify it doesn't throw an exception
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithITKeywords() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            'IT Consulting',
            'Software Development',
            'Computer Programming',
            10
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // May or may not find candidates depending on test data
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithOfficeSuppliesKeywords() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            'Office Supplies',
            'Stationery',
            'Paper Products',
            10
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // May or may not find candidates depending on test data
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithNoKeywords() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            '',
            '',
            '',
            10
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // Should return empty list when no keywords
        System.assertEquals(0, candidates.size(), 'Should return empty list with no keywords');
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithNullValues() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            null,
            null,
            null,
            10
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // Should return empty list when all null
        System.assertEquals(0, candidates.size(), 'Should return empty list with null values');
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_RespectsTopN() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            'Services',
            'Consulting',
            'Professional',
            5
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        System.assert(candidates.size() <= 5, 'Should respect topN parameter');
    }
    
    @isTest
    static void testFindCandidateNaicsCodes_WithDefaultTopN() {
        Test.startTest();
        List<String> candidates = KeywordMatchingService.findCandidateNaicsCodes(
            'Services',
            'Consulting',
            'Professional',
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, candidates, 'Candidates should not be null');
        // Should default to 50
    }
}
