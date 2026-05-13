/**
 * @description Invokes the NAICS matching Flex prompt template via Connect API (Einstein LLM).
 * @description Prompt text lives in Prompt Builder (no Data Library grounding required). Apex supplies spending
 * @description categories plus factor-set candidate codes/descriptions; duplicate category combinations are served
 * @description from LLM_Response_Cache__c before this call when the matching service uses the cache path.
 */
public class LLMService {
    /**
     * When set from an @IsTest class, suggestNaicsCode returns parseLLMResponse(this value) without calling Connect API.
     */
    @TestVisible
    private static String testPromptGenerationJsonOverride;

    /**
     * Input map keys must match the Flex template input API names in Prompt Builder (prefix Input:).
     * Adjust here and redeploy if your template uses different input API names.
     */
    private static final String IN_CATEGORY1 = 'Input:category1';
    private static final String IN_CATEGORY2 = 'Input:category2';
    private static final String IN_CATEGORY3 = 'Input:category3';
    private static final String IN_CANDIDATE_CODES = 'Input:candidateCodes';
    private static final String IN_CANDIDATE_DESCRIPTIONS = 'Input:candidateDescriptions';

    /**
     * @description Suggest NAICS code using the org's Prompt Builder template (Trust Layer as configured on the template).
     */
    public static LLMResponse suggestNaicsCode(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes,
        Map<String, String> candidateCodeDescriptions
    ) {
        if (candidateCodeDescriptions == null) {
            candidateCodeDescriptions = new Map<String, String>();
        }

        if (Test.isRunningTest() && String.isNotBlank(testPromptGenerationJsonOverride)) {
            return parseLLMResponse(testPromptGenerationJsonOverride);
        }

        try {
            String templateApiName = resolveTemplateApiName();
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.isPreview = false;
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = resolveInvocationApplicationName();
            promptInput.additionalConfig.numGenerations = 1;
            promptInput.inputParams = buildTemplateInputParams(
                category1,
                category2,
                category3,
                candidateCodes,
                candidateCodeDescriptions
            );

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                templateApiName,
                promptInput
            );

            String llmResponseJson = extractGenerationText(result);
            if (String.isBlank(llmResponseJson)) {
                LLMResponse errorResponse = new LLMResponse();
                errorResponse.errorMessage = 'Prompt template returned no generation text. Template: ' + templateApiName;
                errorResponse.confidence = 'LOW';
                return errorResponse;
            }

            LLMResponse parsedResponse = parseLLMResponse(llmResponseJson);
            if (String.isNotBlank(parsedResponse.errorMessage)) {
                System.debug('Parse error after prompt template: ' + parsedResponse.errorMessage);
            }
            return parsedResponse;
        } catch (ConnectApi.ConnectApiException e) {
            System.debug('ConnectApiException: ' + e.getMessage());
            LLMResponse errorResponse = new LLMResponse();
            errorResponse.errorMessage = 'Prompt template invocation failed: ' + e.getMessage();
            errorResponse.confidence = 'LOW';
            return errorResponse;
        } catch (Exception e) {
            System.debug('LLMService exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            LLMResponse errorResponse = new LLMResponse();
            errorResponse.errorMessage =
                'LLM call failed: ' + e.getMessage() + ' (Type: ' + e.getTypeName() + ', Line: ' + e.getLineNumber() + ')';
            errorResponse.confidence = 'LOW';
            return errorResponse;
        }
    }

    private static String resolveTemplateApiName() {
        LLM_Config__mdt cfg = LLM_Config__mdt.getInstance('Default');
        if (cfg != null && String.isNotBlank(cfg.Prompt_Template_API_Name__c)) {
            return cfg.Prompt_Template_API_Name__c.trim();
        }
        return 'NAICS_Matching_Prompt';
    }

    private static String resolveInvocationApplicationName() {
        LLM_Config__mdt cfg = LLM_Config__mdt.getInstance('Default');
        if (cfg != null && String.isNotBlank(cfg.Prompt_Invocation_Application_Name__c)) {
            return cfg.Prompt_Invocation_Application_Name__c.trim();
        }
        return 'PromptBuilderPreview';
    }

    private static Map<String, ConnectApi.WrappedValue> buildTemplateInputParams(
        String category1,
        String category2,
        String category3,
        List<String> candidateCodes,
        Map<String, String> candidateCodeDescriptions
    ) {
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put(IN_CATEGORY1, wrapString(category1));
        inputParams.put(IN_CATEGORY2, wrapString(category2));
        inputParams.put(IN_CATEGORY3, wrapString(category3));

        String candidateCodesStr = (candidateCodes != null && !candidateCodes.isEmpty())
            ? String.join(candidateCodes, ', ')
            : 'None provided';
        inputParams.put(IN_CANDIDATE_CODES, wrapString(candidateCodesStr));
        inputParams.put(IN_CANDIDATE_DESCRIPTIONS, wrapString(formatCandidateDescriptions(candidateCodes, candidateCodeDescriptions)));
        return inputParams;
    }

    private static ConnectApi.WrappedValue wrapString(String value) {
        ConnectApi.WrappedValue w = new ConnectApi.WrappedValue();
        w.value = value == null ? '' : value;
        return w;
    }

    /**
     * @description Data assembly for the template (not instructional prompt text).
     */
    private static String formatCandidateDescriptions(List<String> candidateCodes, Map<String, String> candidateCodeDescriptions) {
        if (candidateCodes == null || candidateCodes.isEmpty() || candidateCodeDescriptions == null || candidateCodeDescriptions.isEmpty()) {
            return 'None provided';
        }
        List<String> lines = new List<String>();
        for (String code : candidateCodes) {
            if (candidateCodeDescriptions.containsKey(code) && String.isNotBlank(candidateCodeDescriptions.get(code))) {
                lines.add('- ' + code + ': ' + candidateCodeDescriptions.get(code));
            }
        }
        return lines.isEmpty() ? 'None provided' : String.join(lines, '\n');
    }

    private static String extractGenerationText(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation rep) {
        if (rep == null || rep.generations == null || rep.generations.isEmpty()) {
            return null;
        }
        ConnectApi.EinsteinLLMGenerationItemOutput first = rep.generations[0];
        if (first == null) {
            return null;
        }
        return first.text;
    }

    /**
     * @description Parse and validate LLM JSON response
     */
    @TestVisible
    private static LLMResponse parseLLMResponse(String jsonResponse) {
        LLMResponse response = new LLMResponse();

        if (String.isBlank(jsonResponse)) {
            response.errorMessage = 'Empty response from LLM';
            return response;
        }

        String cleanedResponse = jsonResponse.trim();
        if (cleanedResponse.startsWith('```')) {
            cleanedResponse = cleanedResponse.replaceAll('```json', '').replaceAll('```', '');
            cleanedResponse = cleanedResponse.trim();
        }

        System.debug('Cleaned JSON response: ' + cleanedResponse);

        try {
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(cleanedResponse);

            if (jsonMap.containsKey('suggestedNaicsCode')) {
                Object naicsObj = jsonMap.get('suggestedNaicsCode');
                if (naicsObj != null) {
                    String naicsCode = String.valueOf(naicsObj);
                    if (naicsCode.toLowerCase() != 'null' && naicsCode.trim().length() > 0) {
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

            if (jsonMap.containsKey('confidence')) {
                String conf = String.valueOf(jsonMap.get('confidence'));
                if (conf == 'HIGH' || conf == 'MEDIUM' || conf == 'LOW') {
                    response.confidence = conf;
                }
            }

            if (jsonMap.containsKey('reasoning')) {
                response.reasoning = String.valueOf(jsonMap.get('reasoning'));
            }

            if (jsonMap.containsKey('alternativeNaicsCodes')) {
                List<Object> altCodes = (List<Object>) jsonMap.get('alternativeNaicsCodes');
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

            if (jsonMap.containsKey('uncertaintyFactors')) {
                List<Object> factors = (List<Object>) jsonMap.get('uncertaintyFactors');
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
            response.errorMessage =
                'Failed to parse LLM response: ' +
                e.getMessage() +
                '. Raw response: ' +
                (jsonResponse.length() > 500 ? jsonResponse.substring(0, 500) + '...' : jsonResponse);
        }

        if (String.isBlank(response.suggestedNaicsCode) && String.isBlank(response.errorMessage)) {
            response.errorMessage =
                'LLM did not return a valid NAICS code. Response: ' +
                (cleanedResponse.length() > 500 ? cleanedResponse.substring(0, 500) + '...' : cleanedResponse);
        }

        return response;
    }

    public static Boolean validateNaicsCode(String code) {
        if (String.isBlank(code)) {
            return false;
        }
        return code.length() == 6 && code.isNumeric();
    }

    public class LLMServiceException extends Exception {
    }

    public class LLMResponse {
        public String suggestedNaicsCode { get; set; }
        public String confidence { get; set; }
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
