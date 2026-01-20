/**
 * @description Main service for matching Scope3PcmtItem records to PcmtEmssnFctrSetItem emissions factors
 * @description Uses AI-powered NAICS code matching with Agentforce Knowledge Library grounding
 * @author Your Name
 * @date 2025-01-XX
 */
public class USEEIOMatchingService {
    
    /**
     * @description Main method to match a spend item to an emissions factor (AuraEnabled for LWC)
     * @param scope3PcmtItemId The Scope3PcmtItem record ID to match
     * @return MatchingResult with recommended match, confidence, and alternatives
     */
    @AuraEnabled(cacheable=false)
    public static MatchingResult matchSpendItemToFactor(Id scope3PcmtItemId) {
        MatchingResult result = new MatchingResult(scope3PcmtItemId, 'NO_MATCH');
        
        try {
            // Step 1: Query Scope3PcmtItem with spending categories and parent relationship
            Scope3PcmtItem item = [
                SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                       ProcurementSummaryId, PcmtEmssnFctrSetItemId
                FROM Scope3PcmtItem
                WHERE Id = :scope3PcmtItemId
                LIMIT 1
            ];
            
            // Step 2: Get PcmtEmssnFctrId from parent Scope3PcmtSummary (required for validation)
            if (item.ProcurementSummaryId == null) {
                result.errorMessage = 'Scope3PcmtItem must have a Procurement Summary';
                result.status = 'NO_MATCH';
                return result;
            }
            
            Scope3PcmtSummary summary = [
                SELECT Id, PcmtEmssnFctrId
                FROM Scope3PcmtSummary
                WHERE Id = :item.ProcurementSummaryId
                LIMIT 1
            ];
            
            if (summary.PcmtEmssnFctrId == null) {
                result.errorMessage = 'Procurement Summary must have a Procurement Emissions Factor Set';
                result.status = 'NO_MATCH';
                return result;
            }
            
            Id pcmtEmssnFctrSetId = summary.PcmtEmssnFctrId;
            
            // Step 3: Extract and normalize spending categories
            String normalizedCategories = analyzeSpendingCategories(
                item.SpendingCategory1,
                item.SpendingCategory2,
                item.SpendingCategory3
            );
            
            if (String.isBlank(normalizedCategories)) {
                result.errorMessage = 'No spending categories provided';
                result.status = 'NO_MATCH';
                return result;
            }
            
            // Step 4: Stage 1 - Keyword-based pre-filtering to get candidate NAICS codes
            List<String> candidateCodes = KeywordMatchingService.findCandidateNaicsCodes(
                item.SpendingCategory1,
                item.SpendingCategory2,
                item.SpendingCategory3,
                50 // Top 50 candidates
            );
            
            // Step 5: Stage 2 - Call LLM service with Knowledge Library grounding
            LLMService.LLMResponse llmResponse = LLMService.suggestNaicsCode(
                item.SpendingCategory1,
                item.SpendingCategory2,
                item.SpendingCategory3,
                candidateCodes
            );
            
            if (String.isNotBlank(llmResponse.errorMessage)) {
                result.errorMessage = llmResponse.errorMessage;
                result.status = 'NO_MATCH';
                return result;
            }
            
            if (String.isBlank(llmResponse.suggestedNaicsCode)) {
                result.errorMessage = 'LLM did not suggest a NAICS code';
                result.status = 'NO_MATCH';
                return result;
            }
            
            // Validate NAICS code format
            if (!LLMService.validateNaicsCode(llmResponse.suggestedNaicsCode)) {
                result.errorMessage = 'Invalid NAICS code format: ' + llmResponse.suggestedNaicsCode;
                result.status = 'NO_MATCH';
                return result;
            }
            
            // Step 6: Stage 3 - Find matching PcmtEmssnFctrSetItem records
            List<PcmtEmssnFctrSetItem> matchingFactors = findMatchingFactors(
                llmResponse.suggestedNaicsCode,
                pcmtEmssnFctrSetId
            );
            
            if (matchingFactors.isEmpty()) {
                result.errorMessage = 'No matching emissions factor found for NAICS code: ' + llmResponse.suggestedNaicsCode;
                result.status = 'NO_MATCH';
                result.reasoning = llmResponse.reasoning;
                return result;
            }
            
            // Step 7: Calculate confidence score
            Decimal confidenceScore = calculateConfidenceScore(
                llmResponse.suggestedNaicsCode,
                matchingFactors,
                llmResponse.confidence
            );
            
            // Step 8: Build result with recommended match
            PcmtEmssnFctrSetItem recommendedFactor = matchingFactors[0];
            result.recommendedFactorId = recommendedFactor.Id;
            result.recommendedNaicsCode = llmResponse.suggestedNaicsCode;
            result.recommendedEconomicSector = recommendedFactor.EconomicSector;
            result.emissionsFactorValue = recommendedFactor.TotScpe3EmssnPerMillionSpent;
            result.confidenceScore = confidenceScore;
            result.reasoning = llmResponse.reasoning;
            result.status = confidenceScore >= 0.5 ? 'MATCHED' : 'REQUIRES_REVIEW';
            
            // Step 9: Build alternative matches
            if (matchingFactors.size() > 1) {
                for (Integer i = 1; i < matchingFactors.size() && i < 4; i++) {
                    PcmtEmssnFctrSetItem altFactor = matchingFactors[i];
                    AlternativeMatch altMatch = new AlternativeMatch(
                        altFactor.Id,
                        altFactor.EconomicSectorCode,
                        altFactor.EconomicSector
                    );
                    altMatch.emissionsFactorValue = altFactor.TotScpe3EmssnPerMillionSpent;
                    altMatch.confidenceScore = confidenceScore * 0.9; // Slightly lower for alternatives
                    result.alternatives.add(altMatch);
                }
            }
            
            // Add alternative NAICS codes from LLM response
            if (llmResponse.alternativeNaicsCodes != null && !llmResponse.alternativeNaicsCodes.isEmpty()) {
                for (String altNaics : llmResponse.alternativeNaicsCodes) {
                    if (LLMService.validateNaicsCode(altNaics)) {
                        List<PcmtEmssnFctrSetItem> altFactors = findMatchingFactors(altNaics, pcmtEmssnFctrSetId);
                        if (!altFactors.isEmpty()) {
                            PcmtEmssnFctrSetItem altFactor = altFactors[0];
                            AlternativeMatch altMatch = new AlternativeMatch(
                                altFactor.Id,
                                altFactor.EconomicSectorCode,
                                altFactor.EconomicSector
                            );
                            altMatch.emissionsFactorValue = altFactor.TotScpe3EmssnPerMillionSpent;
                            altMatch.confidenceScore = confidenceScore * 0.8; // Lower for different NAICS codes
                            result.alternatives.add(altMatch);
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            result.errorMessage = 'Error during matching: ' + e.getMessage();
            result.status = 'NO_MATCH';
        }
        
        return result;
    }
    
    /**
     * @description Analyze and normalize spending categories
     * @param cat1 First spending category
     * @param cat2 Second spending category
     * @param cat3 Third spending category
     * @return Normalized combined category text
     */
    public static String analyzeSpendingCategories(String cat1, String cat2, String cat3) {
        List<String> categories = new List<String>();
        
        if (String.isNotBlank(cat1)) {
            categories.add('Category 1: ' + cat1.trim());
        }
        if (String.isNotBlank(cat2)) {
            categories.add('Category 2: ' + cat2.trim());
        }
        if (String.isNotBlank(cat3)) {
            categories.add('Category 3: ' + cat3.trim());
        }
        
        return String.join(categories, '\n');
    }
    
    /**
     * @description Find PcmtEmssnFctrSetItem records matching NAICS code, filtered by factor set
     * @description Only returns factors that are children of the correct PcmtEmssnFctrSet
     * @param naicsCode 6-digit NAICS code
     * @param pcmtEmssnFctrSetId The PcmtEmssnFctrSet ID (from Scope3PcmtSummary)
     * @return List of matching PcmtEmssnFctrSetItem records
     */
    public static List<PcmtEmssnFctrSetItem> findMatchingFactors(String naicsCode, Id pcmtEmssnFctrSetId) {
        if (String.isBlank(naicsCode) || pcmtEmssnFctrSetId == null) {
            return new List<PcmtEmssnFctrSetItem>();
        }
        
        // Validate NAICS code format (must be 6 digits)
        if (!LLMService.validateNaicsCode(naicsCode)) {
            return new List<PcmtEmssnFctrSetItem>();
        }
        
        // Query for exact match - only 6-digit codes exist, no hierarchical fallback needed
        List<PcmtEmssnFctrSetItem> factors = [
            SELECT Id, EconomicSectorCode, EconomicSector, EconomicSectorCategory,
                   TotScpe3EmssnPerMillionSpent, PcmtEmssnFctrSetId
            FROM PcmtEmssnFctrSetItem
            WHERE EconomicSectorCode = :naicsCode
            AND PcmtEmssnFctrSetId = :pcmtEmssnFctrSetId
            ORDER BY EconomicSectorCode
            LIMIT 10
        ];
        
        return factors;
    }
    
    /**
     * @description Calculate confidence score for the match
     * @param suggestedNaics The NAICS code suggested by LLM
     * @param matches List of matching PcmtEmssnFctrSetItem records
     * @param llmConfidence LLM confidence level (HIGH, MEDIUM, LOW)
     * @return Decimal confidence score (0.0 - 1.0)
     */
    public static Decimal calculateConfidenceScore(
        String suggestedNaics,
        List<PcmtEmssnFctrSetItem> matches,
        String llmConfidence
    ) {
        Decimal score = 0.0;
        
        // Factor 1: LLM Confidence (60% weight)
        Decimal llmConfidenceValue = 0.0;
        if (llmConfidence == 'HIGH') {
            llmConfidenceValue = 0.9;
        } else if (llmConfidence == 'MEDIUM') {
            llmConfidenceValue = 0.6;
        } else if (llmConfidence == 'LOW') {
            llmConfidenceValue = 0.3;
        }
        score += llmConfidenceValue * 0.6;
        
        // Factor 2: Match Count (20% weight)
        // Single match = highest confidence, multiple matches = slightly lower
        Decimal matchCountValue = 0.0;
        if (matches.size() == 1) {
            matchCountValue = 1.0;
        } else if (matches.size() > 1) {
            matchCountValue = 0.9; // Multiple matches slightly reduce confidence
        } else {
            matchCountValue = 0.0;
        }
        score += matchCountValue * 0.2;
        
        // Factor 3: Factor Set Validation (20% weight)
        // If we found matches in the correct factor set, that's good
        Decimal factorSetValue = matches.isEmpty() ? 0.0 : 1.0;
        score += factorSetValue * 0.2;
        
        // Ensure score is between 0.0 and 1.0
        return Math.min(1.0, Math.max(0.0, score));
    }
    
    /**
     * @description Apply the match to the Scope3PcmtItem record
     * @param scope3PcmtItemId The Scope3PcmtItem record ID
     * @param pcmtEmssnFctrSetItemId The PcmtEmssnFctrSetItem record ID to link
     * @param confidenceScore The confidence score
     * @param reasoning The LLM reasoning
     * @param matchSource The source of the match (AI Suggested, User Override, Manual Selection)
     * @return Database.SaveResult
     */
    public static Database.SaveResult applyMatch(
        Id scope3PcmtItemId,
        Id pcmtEmssnFctrSetItemId,
        Decimal confidenceScore,
        String reasoning,
        String matchSource
    ) {
        Scope3PcmtItem item = new Scope3PcmtItem(Id = scope3PcmtItemId);
        item.PcmtEmssnFctrSetItemId = pcmtEmssnFctrSetItemId;
        item.Match_Confidence_Score__c = confidenceScore;
        item.Match_Reasoning__c = reasoning;
        item.Match_Source__c = (String.isNotBlank(matchSource) ? matchSource : 'AI Suggested');
        
        return Database.update(item, false);
    }
    
    /**
     * @description Apply match from MatchingResult (AuraEnabled for LWC)
     * @param result The MatchingResult containing match information
     * @return Map with success status and error message if any
     */
    @AuraEnabled
    public static Map<String, Object> applyMatchFromResult(MatchingResult result) {
        Map<String, Object> response = new Map<String, Object>();
        
        if (result == null || result.recommendedFactorId == null) {
            response.put('success', false);
            response.put('error', 'Cannot apply match: Missing recommended factor');
            return response;
        }
        
        try {
            Database.SaveResult saveResult = applyMatch(
                result.scope3PcmtItemId,
                result.recommendedFactorId,
                result.confidenceScore,
                result.reasoning,
                'AI Suggested'
            );
            
            response.put('success', saveResult.isSuccess());
            if (!saveResult.isSuccess()) {
                List<String> errors = new List<String>();
                for (Database.Error err : saveResult.getErrors()) {
                    errors.add(err.getMessage());
                }
                response.put('errors', errors);
                response.put('error', String.join(errors, '; '));
            }
        } catch (Exception e) {
            response.put('success', false);
            response.put('error', e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Custom exception for matching errors
     */
    public class MatchingException extends Exception {}
}
