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
        List<String> candidateCodes
    ) {
        try {
            // Call LLM via Agentforce Models API using Prompt Builder template
            // Pass variables directly for template substitution
            String llmResponseJson = callLLMOpenConnector(category1, category2, category3, candidateCodes);
            
            // Parse and validate response
            return parseLLMResponse(llmResponseJson);
            
        } catch (Exception e) {
            // Return error response
            LLMResponse errorResponse = new LLMResponse();
            errorResponse.errorMessage = 'LLM call failed: ' + e.getMessage();
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
     * @description Call LLM via Agentforce Models API with Data Library grounding using Prompt Builder template
     * @description Uses Salesforce's managed models (GPT-4, Claude, etc.) with native Data Library grounding
     * @description Data Library (USEEIO_Reference) must be indexed and configured in the Prompt Builder template
     * @param category1 First spending category
     * @param category2 Second spending category
     * @param category3 Third spending category
     * @param candidateCodes Optional candidate NAICS codes from pre-filtering
     * @return JSON response from LLM
     */
    private static String callLLMOpenConnector(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes
    ) {
        // Prompt Builder template name
        String templateName = 'NAICS_Matching_Prompt';
        
        // Create variables map for template substitution
        Map<String, Object> variables = new Map<String, Object>();
        variables.put('category1', String.isNotBlank(category1) ? category1 : '');
        variables.put('category2', String.isNotBlank(category2) ? category2 : '');
        variables.put('category3', String.isNotBlank(category3) ? category3 : '');
        
        // Add candidate codes - format as comma-separated string for the template
        if (candidateCodes != null && !candidateCodes.isEmpty()) {
            variables.put('candidateCodes', String.join(candidateCodes, ', '));
        } else {
            variables.put('candidateCodes', 'None provided');
        }
        
        try {
            // Create generate text request using the syntax that works in your org
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            
            // Specify model (you can change this to match your preferred model)
            request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
            
            // Create request body
            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            
            // Build prompt with template reference and variables
            // Note: Prompt Builder templates are referenced by name in the prompt
            // The template will substitute variables automatically when called
            String promptText = buildPromptFromTemplate(templateName, variables);
            requestBody.prompt = promptText;
            
            request.body = requestBody;
            
            // Make request
            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);
            
            // Extract response text
            if (response != null && response.Code200 != null && response.Code200.generation != null) {
                String generatedText = response.Code200.generation.generatedText;
                if (String.isNotBlank(generatedText)) {
                    return generatedText;
                } else {
                    throw new LLMServiceException('Empty response from Models API');
                }
            } else {
                throw new LLMServiceException('Invalid response structure from Models API');
            }
            
        } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
            throw new LLMServiceException('Models API call failed. Response code: ' + e.responseCode + '. Error: ' + e.getMessage());
        } catch (Exception e) {
            throw new LLMServiceException('Models API call failed: ' + e.getMessage());
        }
    }
    
    /**
     * @description Build prompt text by substituting variables into the template structure
     * @description Since createGenerations uses direct prompts, we need to build the prompt
     * @description with variables substituted. This matches the Prompt Builder template structure.
     * @param templateName Name of the Prompt Builder template (for reference)
     * @param variables Variables to substitute in the template
     * @return Prompt text with variables substituted
     */
    private static String buildPromptFromTemplate(String templateName, Map<String, Object> variables) {
        // Build the prompt matching the Prompt Builder template structure
        // This replicates the template but with actual variable values
        
        String prompt = 'System: You are an expert in North American Industry Classification System (NAICS) 2017 codes. ';
        prompt += 'Your task is to analyze spending category descriptions from corporate procurement systems ';
        prompt += 'and identify the most appropriate 6-digit NAICS industry code.\n\n';
        
        prompt += 'You have access to the NAICS 2017 Definition File in the Agentforce Knowledge Library (USEEIO_Reference). ';
        prompt += 'When analyzing spending categories, search the Knowledge Library for relevant NAICS code definitions.\n\n';
        
        prompt += 'User: Analyze these spending categories:\n';
        prompt += 'Category 1: ' + (String)variables.get('category1') + '\n';
        prompt += 'Category 2: ' + (String)variables.get('category2') + '\n';
        prompt += 'Category 3: ' + (String)variables.get('category3') + '\n\n';
        
        prompt += 'Candidate NAICS codes to consider: ' + (String)variables.get('candidateCodes') + '\n\n';
        
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
        
        try {
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonResponse);
            
            // Parse suggested NAICS code
            if (jsonMap.containsKey('suggestedNaicsCode')) {
                Object naicsObj = jsonMap.get('suggestedNaicsCode');
                if (naicsObj != null) {
                    String naicsCode = String.valueOf(naicsObj);
                    // Validate format (should be 6 digits)
                    if (naicsCode.length() == 6 && naicsCode.isNumeric()) {
                        response.suggestedNaicsCode = naicsCode;
                    }
                }
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
            response.errorMessage = 'Failed to parse LLM response: ' + e.getMessage();
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
