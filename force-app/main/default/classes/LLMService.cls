/**
 * @description Service for LLM integration with Agentforce Data Library
 * @description Handles calls to LLM for NAICS code suggestion using Knowledge Library grounding
 * @author Your Name
 * @date 2025-01-XX
 */
public class LLMService {
    
    /**
     * @description Suggest NAICS code based on spending categories using LLM
     * @description Uses Agentforce Knowledge Library for grounding with NAICS definitions
     * @param category1 First spending category
     * @param category2 Second spending category
     * @param category3 Third spending category
     * @param candidateCodes Optional list of candidate NAICS codes to focus on (from pre-filtering)
     * @return LLMResponse wrapper with suggested NAICS code, confidence, and reasoning
     */
    public static LLMResponse suggestNaicsCode(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes,
        Map<String, String> candidateCodeDescriptions
    ) {
        // Handle null candidateCodeDescriptions
        if (candidateCodeDescriptions == null) {
            candidateCodeDescriptions = new Map<String, String>();
        }
        try {
            // Use Models API directly
            // CRITICAL ISSUE: Grounding is NOT enabled with this approach
            // The Models API doesn't support explicit grounding properties
            // We're only mentioning Data Library in prompt text, which doesn't actually enable grounding
            // This means the LLM doesn't have access to the NAICS PDF definitions
            System.debug('Calling Models API directly');
            System.debug('WARNING: Grounding is NOT enabled. LLM does not have access to Data Library.');
            System.debug('The LLM is working from its training data only, not from the NAICS PDF.');
            
            // Build prompt - include candidate codes and their descriptions from factor set
            // Without grounding, we provide context from the factor set itself
            String promptText = buildPromptWithGrounding(category1, category2, category3, candidateCodes, candidateCodeDescriptions);
            
            // Create the request
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
            
            // Create request body
            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            requestBody.prompt = promptText;
            request.body = requestBody;
            
            // TODO: Enable grounding if property becomes available
            // Grounding may need to be configured at the model level in Setup
            // Or we may need to use Prompt Builder template (but retriever issue prevents this)
            
            System.debug('Calling Models API with prompt length: ' + promptText.length());
            System.debug('Callout limit before API call: ' + Limits.getCallouts() + ' of ' + Limits.getLimitCallouts());
            
            // Make the request
            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            System.debug('About to call modelsAPI.createGenerations for categories: ' + category1 + ' | ' + category2 + ' | ' + category3);
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
            System.debug('Models API call completed successfully. Callout limit after: ' + Limits.getCallouts());
            
            // Extract the generated text
            if (response.Code200 == null || response.Code200.generation == null) {
                LLMResponse errorResponse = new LLMResponse();
                errorResponse.errorMessage = 'Models API returned unexpected response structure: ' + JSON.serialize(response);
                errorResponse.confidence = 'LOW';
                return errorResponse;
            }
            
            String llmResponseJson = response.Code200.generation.generatedText;
            System.debug('LLM Response JSON: ' + llmResponseJson);
            
            // Parse and validate response
            LLMResponse parsedResponse = parseLLMResponse(llmResponseJson);
            System.debug('Parsed response - NAICS: ' + parsedResponse.suggestedNaicsCode + ', Confidence: ' + parsedResponse.confidence);
            if (String.isNotBlank(parsedResponse.errorMessage)) {
                System.debug('Parse error: ' + parsedResponse.errorMessage);
            }
            return parsedResponse;
            
        } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
            System.debug('ERROR: ModelsAPI ResponseException caught: ' + e.getMessage());
            System.debug('Response code: ' + e.responseCode);
            System.debug('Callout limit at exception: ' + Limits.getCallouts() + ' of ' + Limits.getLimitCallouts());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            LLMResponse errorResponse = new LLMResponse();
            errorResponse.errorMessage = 'Models API call failed: ' + e.getMessage() + ' (Response code: ' + e.responseCode + ')';
            errorResponse.confidence = 'LOW';
            return errorResponse;
        } catch (Exception e) {
            // Return error response with full details
            System.debug('ERROR: Exception caught in LLMService: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Line number: ' + e.getLineNumber());
            System.debug('Callout limit at exception: ' + Limits.getCallouts() + ' of ' + Limits.getLimitCallouts());
            
            LLMResponse errorResponse = new LLMResponse();
            errorResponse.errorMessage = 'LLM call failed: ' + e.getMessage() + 
                ' (Type: ' + e.getTypeName() + ', Line: ' + e.getLineNumber() + ')';
            errorResponse.confidence = 'LOW';
            return errorResponse;
        }
    }
    
    /**
     * @description Build prompt for LLM with Knowledge Library reference
     * @param category1 First spending category
     * @param category2 Second spending category
     * @param category3 Third spending category
     * @param candidateCodes Optional candidate NAICS codes
     * @return Formatted prompt string
     */
    private static String buildPrompt(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes
    ) {
        String prompt = 'System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. ';
        prompt += 'Your task is to analyze spending category descriptions from corporate procurement systems ';
        prompt += 'and identify the most appropriate 6-digit NAICS industry code.\n\n';
        
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library. ';
        prompt += 'When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + (String.isNotBlank(category1) ? category1 : '') + '\n';
        prompt += 'Category 2: ' + (String.isNotBlank(category2) ? category2 : '') + '\n';
        prompt += 'Category 3: ' + (String.isNotBlank(category3) ? category3 : '') + '\n\n';
        
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            prompt += 'Focus your search in the Knowledge Library on these candidate NAICS codes: ';
            prompt += String.join(candidateCodes, ', ') + '\n\n';
        }
        
        prompt += 'Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate ';
        prompt += '6-digit industry code. For each candidate code, retrieve its full definition including:\n';
        prompt += '- Industry description\n';
        prompt += '- Cross-references\n';
        prompt += '- Examples\n';
        prompt += '- What activities are included/excluded\n\n';
        
        prompt += 'Analyze the spending categories against the retrieved definitions and select the best match.\n\n';
        
        prompt += 'Return your response in JSON format:\n';
        prompt += '{\n';
        prompt += '  "suggestedNaicsCode": "6-digit code or null",\n';
        prompt += '  "confidence": "HIGH|MEDIUM|LOW",\n';
        prompt += '  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",\n';
        prompt += '  "alternativeNaicsCodes": ["code1", "code2"],\n';
        prompt += '  "uncertaintyFactors": ["factor1", "factor2"]\n';
        prompt += '}';
        
        return prompt;
    }
    
    /**
     * @description Build prompt text with explicit Data Library references to trigger grounding
     * @description Uses Models API directly, bypassing Prompt Builder template retriever issues
     * @description Includes candidate code descriptions from factor set since grounding isn't enabled
     */
    private static String buildPromptWithGrounding(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes,
        Map<String, String> candidateCodeDescriptions
    ) {
        String prompt = 'System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. ';
        prompt += 'Your task is to analyze spending category descriptions from corporate procurement systems ';
        prompt += 'and identify the most appropriate 6-digit NAICS industry code.\n\n';
        
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Data Library (USEEIO_Reference). ';
        prompt += 'Search the Knowledge Library (USEEIO_Reference) for relevant NAICS code definitions based on the spending categories provided.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + (String.isNotBlank(category1) ? category1 : '') + '\n';
        prompt += 'Category 2: ' + (String.isNotBlank(category2) ? category2 : '') + '\n';
        prompt += 'Category 3: ' + (String.isNotBlank(category3) ? category3 : '') + '\n\n';
        
        String candidateCodesStr = 'None provided';
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            candidateCodesStr = String.join(candidateCodes, ', ');
        }
        prompt += 'Candidate NAICS codes to consider: ' + candidateCodesStr + '\n\n';
        
        // Include descriptions for candidate codes from the factor set
        if (candidateCodeDescriptions != null && !candidateCodeDescriptions.isEmpty()) {
            prompt += 'Here are the descriptions for the candidate codes from the emissions factor database:\n';
            for (String code : candidateCodes) {
                if (candidateCodeDescriptions.containsKey(code)) {
                    prompt += '- ' + code + ': ' + candidateCodeDescriptions.get(code) + '\n';
                }
            }
            prompt += '\n';
        }
        
        prompt += 'CRITICAL: You MUST select a code from the candidate codes list above if any are provided. ';
        prompt += 'These candidate codes are guaranteed to exist in the emissions factor database. ';
        prompt += 'Do NOT suggest codes that are not in the candidate list.\n\n';
        
        prompt += 'Search the NAICS 2017 Definition File in the Knowledge Library (USEEIO_Reference) to find the most appropriate ';
        prompt += '6-digit industry code. If candidate codes are provided, you MUST choose from those codes. ';
        prompt += 'For each candidate code, retrieve its full definition including:\n';
        prompt += '- Industry description\n';
        prompt += '- Cross-references\n';
        prompt += '- Examples\n';
        prompt += '- What activities are included/excluded\n\n';
        
        prompt += 'Analyze the spending categories against the retrieved NAICS definitions. Match keywords and concepts ';
        prompt += 'from the spending categories to the industry descriptions and examples. ';
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            prompt += 'You MUST select one of these candidate codes: ' + candidateCodesStr + '. ';
        }
        prompt += 'Select the 6-digit NAICS code that best represents the primary economic activity described by the spending categories.\n\n';
        
        prompt += 'CRITICAL: You must return ONLY valid JSON with no markdown, no code blocks, no explanations, and no additional text. ';
        prompt += 'Return your response as a single JSON object:\n';
        prompt += '{\n';
        prompt += '  "suggestedNaicsCode": "6-digit code or null",\n';
        prompt += '  "confidence": "HIGH|MEDIUM|LOW",\n';
        prompt += '  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",\n';
        prompt += '  "alternativeNaicsCodes": ["code1", "code2"],\n';
        prompt += '  "uncertaintyFactors": ["factor1", "factor2"]\n';
        prompt += '}';
        
        return prompt;
    }
    
    /**
     * @description Build prompt text matching the Prompt Builder template structure
     * @description This is used as a fallback until we can invoke the template directly via Connect API
     * @description The prompt includes Knowledge Library references to trigger grounding
     */
    private static String buildPromptWithVariables(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes
    ) {
        String prompt = 'System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. ';
        prompt += 'Your task is to analyze spending category descriptions from corporate procurement systems ';
        prompt += 'and identify the most appropriate 6-digit NAICS industry code.\n\n';
        
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library (USEEIO_Reference). ';
        prompt += 'When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + (String.isNotBlank(category1) ? category1 : '') + '\n';
        prompt += 'Category 2: ' + (String.isNotBlank(category2) ? category2 : '') + '\n';
        prompt += 'Category 3: ' + (String.isNotBlank(category3) ? category3 : '') + '\n\n';
        
        String candidateCodesStr = 'None provided';
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            candidateCodesStr = String.join(candidateCodes, ', ');
        }
        prompt += 'Candidate NAICS codes to consider: ' + candidateCodesStr + '\n\n';
        
        prompt += 'Search the NAICS 2017 Definition File in the Knowledge Library to find the most appropriate ';
        prompt += '6-digit industry code. If candidate codes are provided, focus your search on those codes first. ';
        prompt += 'For each candidate code, retrieve its full definition including:\n';
        prompt += '- Industry description\n';
        prompt += '- Cross-references\n';
        prompt += '- Examples\n';
        prompt += '- What activities are included/excluded\n\n';
        
        prompt += 'Analyze the spending categories against the retrieved definitions and select the best match.\n\n';
        
        prompt += 'Return your response in JSON format:\n';
        prompt += '{\n';
        prompt += '  "suggestedNaicsCode": "6-digit code or null",\n';
        prompt += '  "confidence": "HIGH|MEDIUM|LOW",\n';
        prompt += '  "reasoning": "Detailed explanation referencing specific sections from the NAICS definition",\n';
        prompt += '  "alternativeNaicsCodes": ["code1", "code2"],\n';
        prompt += '  "uncertaintyFactors": ["factor1", "factor2"]\n';
        prompt += '}';
        
        return prompt;
    }
    
    
    /**
     * @description Get model name from Custom Metadata or use default
     * @return Model name string
     */
    private static String getModelName() {
        // Option 1: From Custom Metadata Type (recommended for flexibility)
        // LLM_Config__mdt config = LLM_Config__mdt.getInstance('Default');
        // if (config != null && String.isNotBlank(config.Model__c)) {
        //     return config.Model__c;
        // }
        
        // Option 2: Default to GPT-4o (or another standard model)
        // Standard Agentforce models: 'gpt-4o', 'gpt-4-turbo', 'claude-3-5-sonnet-20241022'
        return 'gpt-4o';
    }
    
    /**
     * @description Parse and validate LLM JSON response
     * @param jsonResponse JSON string from LLM
     * @return LLMResponse wrapper object
     */
    @TestVisible
    private static LLMResponse parseLLMResponse(String jsonResponse) {
        LLMResponse response = new LLMResponse();
        
        if (String.isBlank(jsonResponse)) {
            response.errorMessage = 'Empty response from LLM';
            return response;
        }
        
        // Clean the response - remove markdown code blocks if present
        String cleanedResponse = jsonResponse.trim();
        if (cleanedResponse.startsWith('```')) {
            // Remove markdown code block markers
            cleanedResponse = cleanedResponse.replaceAll('```json', '').replaceAll('```', '');
            cleanedResponse = cleanedResponse.trim();
        }
        
        System.debug('Cleaned JSON response: ' + cleanedResponse);
        
        try {
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(cleanedResponse);
            
            // Parse suggested NAICS code
            if (jsonMap.containsKey('suggestedNaicsCode')) {
                Object naicsObj = jsonMap.get('suggestedNaicsCode');
                if (naicsObj != null) {
                    String naicsCode = String.valueOf(naicsObj);
                    // Handle null string representation
                    if (naicsCode.toLowerCase() != 'null' && naicsCode.trim().length() > 0) {
                        // Validate format (should be 6 digits)
                        if (naicsCode.length() == 6 && naicsCode.isNumeric()) {
                            response.suggestedNaicsCode = naicsCode;
                        } else {
                            System.debug('Invalid NAICS code format: "' + naicsCode + '" (length: ' + naicsCode.length() + ')');
                        }
                    } else {
                        System.debug('LLM returned null for suggestedNaicsCode');
                    }
                }
            } else {
                System.debug('JSON response missing suggestedNaicsCode field');
            }
            
            // Parse confidence
            if (jsonMap.containsKey('confidence')) {
                String conf = String.valueOf(jsonMap.get('confidence'));
                if (conf == 'HIGH' || conf == 'MEDIUM' || conf == 'LOW') {
                    response.confidence = conf;
                }
            }
            
            // Parse reasoning
            if (jsonMap.containsKey('reasoning')) {
                response.reasoning = String.valueOf(jsonMap.get('reasoning'));
            }
            
            // Parse alternative codes
            if (jsonMap.containsKey('alternativeNaicsCodes')) {
                List<Object> altCodes = (List<Object>)jsonMap.get('alternativeNaicsCodes');
                if (altCodes != null) {
                    response.alternativeNaicsCodes = new List<String>();
                    for (Object code : altCodes) {
                        String codeStr = String.valueOf(code);
                        if (codeStr.length() == 6 && codeStr.isNumeric()) {
                            response.alternativeNaicsCodes.add(codeStr);
                        }
                    }
                }
            }
            
            // Parse uncertainty factors
            if (jsonMap.containsKey('uncertaintyFactors')) {
                List<Object> factors = (List<Object>)jsonMap.get('uncertaintyFactors');
                if (factors != null) {
                    response.uncertaintyFactors = new List<String>();
                    for (Object factor : factors) {
                        response.uncertaintyFactors.add(String.valueOf(factor));
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('JSON parsing exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Raw response that failed to parse: ' + jsonResponse);
            response.errorMessage = 'Failed to parse LLM response: ' + e.getMessage() + 
                '. Raw response: ' + (jsonResponse.length() > 500 ? jsonResponse.substring(0, 500) + '...' : jsonResponse);
        }
        
        // If no NAICS code was parsed and no error was set, add a helpful message
        if (String.isBlank(response.suggestedNaicsCode) && String.isBlank(response.errorMessage)) {
            response.errorMessage = 'LLM did not return a valid NAICS code. Response: ' + 
                (cleanedResponse.length() > 500 ? cleanedResponse.substring(0, 500) + '...' : cleanedResponse);
        }
        
        return response;
    }
    
    /**
     * @description Validate NAICS code format
     * @param code NAICS code to validate
     * @return True if valid 6-digit code
     */
    public static Boolean validateNaicsCode(String code) {
        if (String.isBlank(code)) {
            return false;
        }
        // Must be exactly 6 digits
        return code.length() == 6 && code.isNumeric();
    }
    
    /**
     * @description Custom exception for LLM service errors
     */
    public class LLMServiceException extends Exception {}
    
    /**
     * @description Wrapper class for LLM response
     */
    public class LLMResponse {
        public String suggestedNaicsCode { get; set; }
        public String confidence { get; set; } // HIGH, MEDIUM, LOW
        public String reasoning { get; set; }
        public List<String> alternativeNaicsCodes { get; set; }
        public List<String> uncertaintyFactors { get; set; }
        public String errorMessage { get; set; }
        
        public LLMResponse() {
            this.alternativeNaicsCodes = new List<String>();
            this.uncertaintyFactors = new List<String>();
            this.confidence = 'LOW';
        }
    }
}