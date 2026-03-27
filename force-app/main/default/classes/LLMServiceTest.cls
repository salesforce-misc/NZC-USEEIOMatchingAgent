/**
 * @description Test class for LLMService
 * @author Your Name
 * @date 2025-01-XX
 */
@isTest
private class LLMServiceTest {
    
    @isTest
    static void testValidateNaicsCode_ValidCodes() {
        System.assert(LLMService.validateNaicsCode('541211'), 'Should validate 6-digit code');
        System.assert(LLMService.validateNaicsCode('123456'), 'Should validate 6-digit code');
        System.assert(LLMService.validateNaicsCode('000000'), 'Should validate 6-digit code');
    }
    
    @isTest
    static void testValidateNaicsCode_InvalidCodes() {
        System.assert(!LLMService.validateNaicsCode(null), 'Should reject null');
        System.assert(!LLMService.validateNaicsCode(''), 'Should reject empty string');
        System.assert(!LLMService.validateNaicsCode('54121'), 'Should reject 5-digit code');
        System.assert(!LLMService.validateNaicsCode('5412111'), 'Should reject 7-digit code');
        System.assert(!LLMService.validateNaicsCode('ABC123'), 'Should reject non-numeric');
        System.assert(!LLMService.validateNaicsCode('54-211'), 'Should reject with dashes');
    }
    
    @isTest
    static void testSuggestNaicsCode_ThrowsException() {
        LLMService.testPromptGenerationJsonOverride = null;
        Test.startTest();
        LLMService.LLMResponse response = LLMService.suggestNaicsCode(
            'Accounting Services',
            'Financial Consulting',
            null,
            new List<String>{ '541211', '541219' },
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(
            String.isNotBlank(response.errorMessage),
            'Should have error message when template is unavailable or Connect API fails in test context'
        );
    }

    @isTest
    static void testSuggestNaicsCode_WithMockPromptJson() {
        LLMService.testPromptGenerationJsonOverride =
            '{"suggestedNaicsCode":"541211","confidence":"HIGH","reasoning":"From mock template","alternativeNaicsCodes":[],"uncertaintyFactors":[]}';
        try {
            Test.startTest();
            LLMService.LLMResponse response = LLMService.suggestNaicsCode(
                'Accounting',
                'Tax',
                null,
                new List<String>{ '541211' },
                null
            );
            Test.stopTest();

            System.assertEquals('541211', response.suggestedNaicsCode);
            System.assertEquals('HIGH', response.confidence);
            System.assert(String.isBlank(response.errorMessage), 'Mock path should not set errorMessage');
        } finally {
            LLMService.testPromptGenerationJsonOverride = null;
        }
    }
    
    @isTest
    static void testParseLLMResponse_ValidJSON() {
        String jsonResponse = '{"suggestedNaicsCode":"541211","confidence":"HIGH","reasoning":"Test reasoning","alternativeNaicsCodes":["541219"],"uncertaintyFactors":[]}';
        
        LLMService.LLMResponse response = LLMService.parseLLMResponse(jsonResponse);
        
        System.assertEquals('541211', response.suggestedNaicsCode, 'Should parse NAICS code');
        System.assertEquals('HIGH', response.confidence, 'Should parse confidence');
        System.assertEquals('Test reasoning', response.reasoning, 'Should parse reasoning');
        System.assertNotEquals(null, response.alternativeNaicsCodes, 'Should parse alternatives');
        System.assertEquals(1, response.alternativeNaicsCodes.size(), 'Should have one alternative');
    }
    
    @isTest
    static void testParseLLMResponse_InvalidJSON() {
        String jsonResponse = 'invalid json';
        
        LLMService.LLMResponse response = LLMService.parseLLMResponse(jsonResponse);
        
        System.assert(String.isNotBlank(response.errorMessage), 'Should have error message for invalid JSON');
    }
    
    @isTest
    static void testParseLLMResponse_EmptyResponse() {
        LLMService.LLMResponse response = LLMService.parseLLMResponse('');
        
        System.assert(String.isNotBlank(response.errorMessage), 'Should have error message for empty response');
    }
    
    @isTest
    static void testParseLLMResponse_MissingFields() {
        String jsonResponse = '{"confidence":"HIGH"}';
        
        LLMService.LLMResponse response = LLMService.parseLLMResponse(jsonResponse);
        
        System.assertEquals('HIGH', response.confidence, 'Should parse available fields');
        System.assertEquals(null, response.suggestedNaicsCode, 'Should handle missing fields');
    }
    
    @isTest
    static void testParseLLMResponse_WithNullNaicsCode() {
        String jsonResponse = '{"suggestedNaicsCode":null,"confidence":"LOW","reasoning":"No match found"}';
        
        LLMService.LLMResponse response = LLMService.parseLLMResponse(jsonResponse);
        
        System.assertEquals(null, response.suggestedNaicsCode, 'Should handle null NAICS code');
        System.assertEquals('LOW', response.confidence, 'Should parse confidence');
    }
}
