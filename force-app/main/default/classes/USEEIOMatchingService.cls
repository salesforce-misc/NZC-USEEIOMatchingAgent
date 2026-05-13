/**
 * @description Main service for matching Scope3PcmtItem records to PcmtEmssnFctrSetItem emissions factors
 * @description Uses AI-powered NAICS code matching with Agentforce Models API
 * @description Implements Response Caching to reduce LLM API costs by storing responses in LLM_Response_Cache__c
 * @author Your Name
 * @date 2025-01-XX
 */
public class USEEIOMatchingService {
    
    /**
     * @description Bulk matching method to process multiple Scope3PcmtItem records
     * @description Processes items in batches to respect governor limits
     * @param scope3PcmtItemIds List of Scope3PcmtItem record IDs to match
     * @param batchSize Number of items to process per batch (default: 10, max recommended: 20)
     * @return BulkMatchingResult with results for all items
     */
    @AuraEnabled(cacheable=false)
    public static BulkMatchingResult matchSpendItemsToFactors(List<Id> scope3PcmtItemIds, Integer batchSize) {
        BulkMatchingResult bulkResult = new BulkMatchingResult(scope3PcmtItemIds != null ? scope3PcmtItemIds.size() : 0);
        
        if (scope3PcmtItemIds == null || scope3PcmtItemIds.isEmpty()) {
            bulkResult.status = 'ERROR';
            bulkResult.errors.add('No Scope3PcmtItem IDs provided');
            bulkResult.isComplete = true;
            return bulkResult;
        }
        
        // Set default batch size if not provided
        if (batchSize == null || batchSize <= 0) {
            batchSize = 10; // Conservative default to respect callout limits
        }
        
        // Limit batch size to respect callout limits (100 callouts per transaction)
        // Each match requires 1 LLM callout, so max 50-80 items per transaction to be safe
        if (batchSize > 50) {
            batchSize = 50;
        }
        
        try {
            // Process items in batches
            Integer totalItems = scope3PcmtItemIds.size();
            Integer processed = 0;
            
            // Process in chunks to respect governor limits
            for (Integer i = 0; i < totalItems; i += batchSize) {
                Integer endIndex = Math.min(i + batchSize, totalItems);
                List<Id> batch = new List<Id>();
                for (Integer j = i; j < endIndex; j++) {
                    batch.add(scope3PcmtItemIds[j]);
                }
                
                // Process this batch
                processBatch(batch, bulkResult);
                
                processed += batch.size();
                bulkResult.processedItems = processed;
                
                // Check governor limits - if we're getting close, stop and return partial results
                if (Limits.getCallouts() >= 90 || Limits.getCpuTime() >= 9000) {
                    bulkResult.status = 'IN_PROGRESS';
                    bulkResult.errors.add('Processing stopped due to governor limits. Processed ' + processed + ' of ' + totalItems + ' items.');
                    return bulkResult;
                }
            }
            
            bulkResult.status = 'COMPLETE';
            bulkResult.isComplete = true;
            
        } catch (Exception e) {
            bulkResult.status = 'ERROR';
            bulkResult.errors.add('Bulk matching failed: ' + e.getMessage());
            bulkResult.isComplete = true;
        }
        
        return bulkResult;
    }
    
    /**
     * @description Process a batch of Scope3PcmtItem records
     * @param batch List of Scope3PcmtItem IDs to process
     * @param bulkResult BulkMatchingResult to update with results
     */
    private static void processBatch(List<Id> batch, BulkMatchingResult bulkResult) {
        // Query all items in batch upfront to minimize SOQL queries
        Map<Id, Scope3PcmtItem> itemsMap = new Map<Id, Scope3PcmtItem>([
            SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                   ProcurementSummaryId, PcmtEmssnFctrSetItemId
            FROM Scope3PcmtItem
            WHERE Id IN :batch
        ]);
        
        // Query all parent summaries in one query
        Set<Id> summaryIds = new Set<Id>();
        for (Scope3PcmtItem item : itemsMap.values()) {
            if (item.ProcurementSummaryId != null) {
                summaryIds.add(item.ProcurementSummaryId);
            }
        }
        
        Map<Id, Scope3PcmtSummary> summariesMap = new Map<Id, Scope3PcmtSummary>();
        if (!summaryIds.isEmpty()) {
            summariesMap = new Map<Id, Scope3PcmtSummary>([
                SELECT Id, PcmtEmssnFctrId
                FROM Scope3PcmtSummary
                WHERE Id IN :summaryIds
            ]);
        }
        
        // Process each item in the batch
        for (Id itemId : batch) {
            Scope3PcmtItem item = itemsMap.get(itemId);
            if (item == null) {
                MatchingResult errorResult = new MatchingResult(itemId, 'NO_MATCH');
                errorResult.errorMessage = 'Scope3PcmtItem not found';
                bulkResult.results.add(errorResult);
                bulkResult.failedMatches++;
                continue;
            }
            
            try {
                // Call the single-item matching method
                MatchingResult result = matchSpendItemToFactorInternal(item, summariesMap.get(item.ProcurementSummaryId));
                bulkResult.results.add(result);
                
                if (result.status == 'MATCHED' || result.status == 'REQUIRES_REVIEW') {
                    bulkResult.successfulMatches++;
                } else {
                    bulkResult.failedMatches++;
                }
                
            } catch (Exception e) {
                MatchingResult errorResult = new MatchingResult(itemId, 'NO_MATCH');
                errorResult.errorMessage = 'Error processing item: ' + e.getMessage();
                bulkResult.results.add(errorResult);
                bulkResult.failedMatches++;
                bulkResult.errors.add('Item ' + itemId + ': ' + e.getMessage());
            }
        }
    }
    
    /**
     * @description Internal matching method that accepts pre-queried records
     * @description This avoids redundant queries when processing in bulk
     * @param item The Scope3PcmtItem record (already queried)
     * @param summary The Scope3PcmtSummary record (already queried, can be null)
     * @return MatchingResult with recommended match
     */
    public static MatchingResult matchSpendItemToFactorInternal(Scope3PcmtItem item, Scope3PcmtSummary summary) {
        MatchingResult result = new MatchingResult(item.Id, 'NO_MATCH');
        
        try {
            // Validate parent summary
            if (summary == null) {
                result.errorMessage = 'Scope3PcmtItem must have a Procurement Summary';
                result.status = 'NO_MATCH';
                return result;
            }
            
            if (summary.PcmtEmssnFctrId == null) {
                result.errorMessage = 'Procurement Summary must have a Procurement Emissions Factor Set';
                result.status = 'NO_MATCH';
                return result;
            }
            
            Id pcmtEmssnFctrSetId = summary.PcmtEmssnFctrId;
            
            // Extract and normalize spending categories
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
            
            // Step 4b: Get candidate code details from factor set to provide context to LLM
            Map<String, String> candidateCodeDescriptions = new Map<String, String>();
            if (candidateCodes != null && !candidateCodes.isEmpty()) {
                List<PcmtEmssnFctrSetItem> candidateFactors = [
                    SELECT EconomicSectorCode, EconomicSector, EconomicSectorCategory
                    FROM PcmtEmssnFctrSetItem
                    WHERE EconomicSectorCode IN :candidateCodes
                    AND PcmtEmssnFctrSetId = :pcmtEmssnFctrSetId
                    LIMIT 50
                ];
                for (PcmtEmssnFctrSetItem factor : candidateFactors) {
                    if (factor.EconomicSectorCode != null) {
                        String description = (factor.EconomicSector != null ? factor.EconomicSector : '') + 
                                     (factor.EconomicSectorCategory != null ? ' - ' + factor.EconomicSectorCategory : '');
                        candidateCodeDescriptions.put(factor.EconomicSectorCode, description);
                    }
                }
            }
            
            // Step 5: Stage 2 - Check Response Cache first, then call LLM if needed
            LLMService.LLMResponse llmResponse = null;
            Boolean fromCache = false;
            
            try {
                // Check cache before calling LLM
                llmResponse = LLMResponseCache.getCachedResponse(
                    item.SpendingCategory1,
                    item.SpendingCategory2,
                    item.SpendingCategory3,
                    pcmtEmssnFctrSetId
                );
                
                if (llmResponse != null) {
                    fromCache = true;
                    System.debug('Cache hit for item: ' + item.Id);
                }
            } catch (Exception cacheEx) {
                // If cache lookup fails, log but continue with LLM call
                System.debug('Cache lookup failed (continuing with LLM call): ' + cacheEx.getMessage());
            }
            
            // If not found in cache, call LLM service
            if (llmResponse == null) {
                System.debug('Cache miss - calling LLM for item: ' + item.Id);
                llmResponse = LLMService.suggestNaicsCode(
                    item.SpendingCategory1,
                    item.SpendingCategory2,
                    item.SpendingCategory3,
                    candidateCodes,
                    candidateCodeDescriptions
                );
                
                // NOTE: Cache save is deferred to avoid pending DML during callout phase
                // Cache will be saved after all callouts are complete (handled in BulkMatchingBatch)
            }
            
            if (llmResponse == null) {
                result.errorMessage = 'LLM service returned null response';
                result.status = 'NO_MATCH';
                return result;
            }
            
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
                System.debug('Invalid NAICS code format for item ' + item.Id + ': ' + llmResponse.suggestedNaicsCode);
                result.errorMessage = 'Invalid NAICS code format: ' + llmResponse.suggestedNaicsCode;
                result.status = 'NO_MATCH';
                return result;
            }
            
            // Step 6: Stage 3 - Find matching PcmtEmssnFctrSetItem records
            System.debug('Searching for matching factors for NAICS code: ' + llmResponse.suggestedNaicsCode + 
                        ' in factor set: ' + pcmtEmssnFctrSetId);
            List<PcmtEmssnFctrSetItem> matchingFactors = findMatchingFactors(
                llmResponse.suggestedNaicsCode,
                pcmtEmssnFctrSetId
            );
            
            System.debug('Found ' + matchingFactors.size() + ' matching factors for NAICS code: ' + llmResponse.suggestedNaicsCode);
            
            if (matchingFactors.isEmpty()) {
                System.debug('No matching emissions factor found for item ' + item.Id + 
                            ' with code: ' + llmResponse.suggestedNaicsCode);
                
                // Enhanced EEIO detection: check sector range AND existence in other factor sets
                Boolean isEeioCode = isLikelyEeioCode(
                    llmResponse.suggestedNaicsCode, 
                    llmResponse.confidence, 
                    pcmtEmssnFctrSetId  // The linked factor set (contains NAICS codes)
                );
                
                if (isEeioCode) {
                    // Determine the specific reason for EEIO detection
                    String sectorStr = llmResponse.suggestedNaicsCode.substring(0, 2);
                    Integer sector = Integer.valueOf(sectorStr);
                    Boolean isOutsideRange = sector < 11 || sector > 92;
                    Boolean existsInOtherFactorSet = codeExistsInOtherFactorSet(
                        llmResponse.suggestedNaicsCode, 
                        pcmtEmssnFctrSetId
                    );
                    
                    if (isOutsideRange) {
                        // Original case: sector outside NAICS range
                        result.errorMessage = 'LLM suggested code ' + llmResponse.suggestedNaicsCode + 
                            ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                            'This code is not available in the selected emissions factor set, which uses NAICS codes. ' +
                            'The LLM reasoning is preserved for reference.';
                        result.reasoning = llmResponse.reasoning + 
                            '\n\n[Note: The LLM identified an EEIO code (' + llmResponse.suggestedNaicsCode + 
                            ') instead of a NAICS code. Please review the spending categories and select an appropriate NAICS code from the factor set.]';
                    } else if (existsInOtherFactorSet && llmResponse.confidence == 'HIGH') {
                        // New case: code exists in other factor sets but not in linked NAICS factor set
                        result.errorMessage = 'LLM suggested code ' + llmResponse.suggestedNaicsCode + 
                            ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                            'While this code follows NAICS format, it exists in other emissions factor sets in the system but not in the selected factor set (which contains NAICS codes). ' +
                            'The LLM was highly confident in this match, suggesting it may have identified an EEIO code. ' +
                            'Please review the spending categories and select an appropriate NAICS code from the selected factor set.';
                        result.reasoning = llmResponse.reasoning + 
                            '\n\n[Note: The LLM identified code ' + llmResponse.suggestedNaicsCode + 
                            ' with HIGH confidence. This code exists in other emissions factor sets but not in the selected factor set (which contains NAICS codes). ' +
                            'This suggests the LLM may have identified an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                            'Please review the spending categories and select an appropriate NAICS code from the selected factor set.]';
                    } else {
                        // Fallback to original message
                        result.errorMessage = 'LLM suggested code ' + llmResponse.suggestedNaicsCode + 
                            ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                            'This code is not available in the selected emissions factor set, which uses NAICS codes.';
                        result.reasoning = llmResponse.reasoning + 
                            '\n\n[Note: The LLM identified an EEIO code (' + llmResponse.suggestedNaicsCode + 
                            ') instead of a NAICS code. Please review the spending categories and select an appropriate NAICS code from the factor set.]';
                    }
                } else {
                    // Valid NAICS code format but not in factor set (existing logic)
                    result.errorMessage = 'LLM suggested NAICS code ' + llmResponse.suggestedNaicsCode + 
                        ', but this code is not available in the selected emissions factor set. ' +
                        'The LLM reasoning is preserved for reference.';
                    result.reasoning = llmResponse.reasoning;
                }
                
                result.status = 'NO_MATCH';
                // Set confidence score based on LLM confidence
                if (llmResponse.confidence == 'HIGH') {
                    result.confidenceScore = 0.3; // LLM was confident, but code not available
                } else if (llmResponse.confidence == 'MEDIUM') {
                    result.confidenceScore = 0.2;
                } else {
                    result.confidenceScore = 0.1;
                }
                return result;
            }
            
            // Step 7: Calculate confidence score
            Decimal confidenceScore = calculateConfidenceScore(
                llmResponse.suggestedNaicsCode,
                matchingFactors,
                llmResponse.confidence
            );
            
            System.debug('Confidence score for item ' + item.Id + ': ' + confidenceScore + 
                        ' (LLM confidence: ' + llmResponse.confidence + ', factors: ' + matchingFactors.size() + ')');
            
            // Step 8: Build result with recommended match
            PcmtEmssnFctrSetItem recommendedFactor = matchingFactors[0];
            result.recommendedFactorId = recommendedFactor.Id;
            result.recommendedNaicsCode = llmResponse.suggestedNaicsCode;
            result.recommendedEconomicSector = recommendedFactor.EconomicSector;
            result.emissionsFactorValue = recommendedFactor.TotScpe3EmssnPerMillionSpent;
            result.confidenceScore = confidenceScore;
            result.reasoning = llmResponse.reasoning;
            result.status = confidenceScore >= 0.5 ? 'MATCHED' : 'REQUIRES_REVIEW';
            
            System.debug('Final result for item ' + item.Id + ': status=' + result.status + 
                        ', confidence=' + confidenceScore + ', factorId=' + result.recommendedFactorId);
            
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
                    altMatch.confidenceScore = confidenceScore * 0.9;
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
                            altMatch.confidenceScore = confidenceScore * 0.8;
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
     * @description Main method to match a spend item to an emissions factor (AuraEnabled for LWC)
     * @param scope3PcmtItemId The Scope3PcmtItem record ID to match
     * @return MatchingResult with recommended match, confidence, and alternatives
     */
    @AuraEnabled(cacheable=false)
    public static MatchingResult matchSpendItemToFactor(Id scope3PcmtItemId) {
        // Query the item and summary, then call internal method
        Scope3PcmtItem item = [
            SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                   ProcurementSummaryId, PcmtEmssnFctrSetItemId
            FROM Scope3PcmtItem
            WHERE Id = :scope3PcmtItemId
            LIMIT 1
        ];
        
        Scope3PcmtSummary summary = null;
        if (item.ProcurementSummaryId != null) {
            List<Scope3PcmtSummary> summaries = [
                SELECT Id, PcmtEmssnFctrId
                FROM Scope3PcmtSummary
                WHERE Id = :item.ProcurementSummaryId
                LIMIT 1
            ];
            if (!summaries.isEmpty()) {
                summary = summaries[0];
            }
        }
        
        return matchSpendItemToFactorInternal(item, summary);
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
     * @description Check if a NAICS code exists in factor sets OTHER than the specified one
     * @description Used to detect if a code exists in EEIO factor sets but not in the NAICS factor set
     * @param naicsCode 6-digit code to check
     * @param excludeFactorSetId Factor set ID to exclude from search (the NAICS factor set)
     * @return True if code exists in any other factor set, false otherwise
     */
    public static Boolean codeExistsInOtherFactorSet(String naicsCode, Id excludeFactorSetId) {
        if (String.isBlank(naicsCode) || !LLMService.validateNaicsCode(naicsCode) || excludeFactorSetId == null) {
            return false;
        }
        
        // Query other factor sets (excluding the linked one) to see if this code exists
        List<PcmtEmssnFctrSetItem> existingFactors = [
            SELECT Id
            FROM PcmtEmssnFctrSetItem
            WHERE EconomicSectorCode = :naicsCode
            AND PcmtEmssnFctrSetId != :excludeFactorSetId
            LIMIT 1
        ];
        
        return !existingFactors.isEmpty();
    }
    
    /**
     * @description Check if a code is likely an EEIO code rather than a NAICS code
     * @description NAICS codes have sector ranges 11-92 (first 2 digits)
     * @description EEIO codes are 6-digit numeric but may fall outside NAICS sector ranges
     * @param code 6-digit numeric code
     * @return True if code appears to be EEIO (outside NAICS sector ranges)
     */
    public static Boolean isLikelyEeioCode(String code) {
        return isLikelyEeioCode(code, null, null);
    }
    
    /**
     * @description Check if a code is likely an EEIO code rather than a NAICS code
     * @description Enhanced version that checks sector range and existence in other factor sets
     * @param code 6-digit numeric code
     * @param llmConfidence LLM confidence level (HIGH, MEDIUM, LOW) - optional
     * @param linkedFactorSetId The factor set ID linked to Procurement Summary (contains NAICS codes)
     * @return True if code appears to be EEIO
     */
    public static Boolean isLikelyEeioCode(String code, String llmConfidence, Id linkedFactorSetId) {
        // First check: sector range (existing logic)
        if (String.isBlank(code) || code.length() != 6 || !code.isNumeric()) {
            return false;
        }
        
        String sectorStr = code.substring(0, 2);
        Integer sector = Integer.valueOf(sectorStr);
        
        // Codes outside NAICS sector range (11-92) are likely EEIO
        if (sector < 11 || sector > 92) {
            return true;
        }
        
        // Second check: if code is in valid NAICS range but exists in OTHER factor sets
        // (not the linked one) AND LLM confidence is HIGH, it's likely an EEIO code
        if (linkedFactorSetId != null && llmConfidence == 'HIGH') {
            Boolean existsInOtherFactorSet = codeExistsInOtherFactorSet(code, linkedFactorSetId);
            if (existsInOtherFactorSet) {
                return true; // Code exists in other factor sets but not linked one - likely EEIO
            }
        }
        
        return false;
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
    
    // ==========================================
    // Bulk Matching Methods for LWC Integration
    // ==========================================
    
    /**
     * @description Start bulk matching process for a Scope3PcmtSummary
     * @param scope3PcmtSummaryId Scope3PcmtSummary record ID
     * @return Map with success status and job ID
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> startBulkMatching(Id scope3PcmtSummaryId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            // Validate summary exists and has factor set
            Scope3PcmtSummary summary = [
                SELECT Id, PcmtEmssnFctrId, Bulk_Matching_Status__c
                FROM Scope3PcmtSummary
                WHERE Id = :scope3PcmtSummaryId
                LIMIT 1
            ];
            
            if (summary.PcmtEmssnFctrId == null) {
                response.put('success', false);
                response.put('error', 'Procurement Summary must have a Procurement Emissions Factor Set');
                return response;
            }
            
            // Check if already in progress
            if (summary.Bulk_Matching_Status__c == 'In Progress') {
                response.put('success', false);
                response.put('error', 'Bulk matching is already in progress for this summary');
                return response;
            }
            
            // Check if there are items to process
            Integer itemCount = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND PcmtEmssnFctrSetItemId = null
            ];
            
            if (itemCount == 0) {
                response.put('success', false);
                response.put('error', 'No unmatched items found to process');
                return response;
            }
            
            // Enqueue the queueable job
            BulkMatchingQueueable queueable = new BulkMatchingQueueable(scope3PcmtSummaryId);
            Id jobId = System.enqueueJob(queueable);
            
            response.put('success', true);
            response.put('jobId', String.valueOf(jobId));
            response.put('message', 'Bulk matching started successfully');
            
        } catch (Exception e) {
            response.put('success', false);
            response.put('error', 'Failed to start bulk matching: ' + e.getMessage());
            System.debug('Error starting bulk matching: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * @description Get current bulk matching status for a Scope3PcmtSummary
     * @param scope3PcmtSummaryId Scope3PcmtSummary record ID
     * @return BulkMatchingStatus with current status and statistics
     */
    @AuraEnabled(cacheable=true)
    public static BulkMatchingStatus getMatchingStatus(Id scope3PcmtSummaryId) {
        // #region agent log
        System.debug('[DEBUG] getMatchingStatus - ENTRY: scope3PcmtSummaryId=' + scope3PcmtSummaryId);
        // #endregion
        
        BulkMatchingStatus status = new BulkMatchingStatus();
        
        try {
            Scope3PcmtSummary summary = [
                SELECT Id, Bulk_Matching_Status__c, Bulk_Matching_Job_Id__c,
                       Bulk_Matching_Completed_Date__c, Bulk_Matching_Items_Processed__c,
                       Bulk_Matching_Items_Matched__c, Bulk_Matching_Items_Needing_Review__c,
                       Bulk_Matching_Cache_Hits__c, Bulk_Matching_Deduplicated__c,
                       Bulk_Matching_LLM_Calls__c, Bulk_Matching_Cost_Saved__c
                FROM Scope3PcmtSummary
                WHERE Id = :scope3PcmtSummaryId
                LIMIT 1
            ];
            
            // #region agent log
            System.debug('[DEBUG] getMatchingStatus - QUERIED SUMMARY: processed=' + summary.Bulk_Matching_Items_Processed__c + ', matched=' + summary.Bulk_Matching_Items_Matched__c + ', needsReview=' + summary.Bulk_Matching_Items_Needing_Review__c + ', status=' + summary.Bulk_Matching_Status__c);
            // #endregion
            
            // Map status from picklist to enum
            if (summary.Bulk_Matching_Status__c == 'Not Started') {
                status.status = 'NOT_STARTED';
            } else if (summary.Bulk_Matching_Status__c == 'In Progress') {
                status.status = 'IN_PROGRESS';
            } else if (summary.Bulk_Matching_Status__c == 'Complete') {
                status.status = 'COMPLETE';
            } else if (summary.Bulk_Matching_Status__c == 'Error') {
                status.status = 'ERROR';
            } else {
                status.status = 'NOT_STARTED';
            }
            
            status.jobId = summary.Bulk_Matching_Job_Id__c;
            status.completedDate = summary.Bulk_Matching_Completed_Date__c;
            status.processedItems = summary.Bulk_Matching_Items_Processed__c != null ? summary.Bulk_Matching_Items_Processed__c.intValue() : 0;
            status.matchedItems = summary.Bulk_Matching_Items_Matched__c != null ? summary.Bulk_Matching_Items_Matched__c.intValue() : 0;
            status.needsReviewItems = summary.Bulk_Matching_Items_Needing_Review__c != null ? summary.Bulk_Matching_Items_Needing_Review__c.intValue() : 0;
            status.cacheHits = summary.Bulk_Matching_Cache_Hits__c != null ? summary.Bulk_Matching_Cache_Hits__c.intValue() : 0;
            status.deduplicated = summary.Bulk_Matching_Deduplicated__c != null ? summary.Bulk_Matching_Deduplicated__c.intValue() : 0;
            status.llmCalls = summary.Bulk_Matching_LLM_Calls__c != null ? summary.Bulk_Matching_LLM_Calls__c.intValue() : 0;
            status.costSaved = summary.Bulk_Matching_Cost_Saved__c != null ? summary.Bulk_Matching_Cost_Saved__c : 0.0;
            
            // Get total items count - count ALL items for this summary
            Integer totalItems = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
            ];
            
            // Also count unmatched items to see the difference
            Integer unmatchedItems = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND PcmtEmssnFctrSetItemId = null
            ];
            
            status.totalItems = totalItems;
            
            // #region agent log
            System.debug('[DEBUG] getMatchingStatus - CALCULATED: totalItems=' + totalItems + ', unmatchedItems=' + unmatchedItems + ', processedItems=' + status.processedItems + ', matchedItems=' + status.matchedItems + ', needsReviewItems=' + status.needsReviewItems);
            // #endregion
            
            // Calculate progress
            status.calculateProgress();
            
            // #region agent log
            System.debug('[DEBUG] getMatchingStatus - PROGRESS: progressPercentage=' + status.progressPercentage + ', status=' + status.status);
            // #endregion
            
        } catch (Exception e) {
            status.status = 'ERROR';
            status.errorMessage = 'Failed to get matching status: ' + e.getMessage();
            System.debug('Error getting matching status: ' + e.getMessage());
        }
        
        return status;
    }
    
    /**
     * @description Get items that need manual review (low confidence or no match)
     * Only returns items with Review_Status__c = 'Pending Review' or null
     * @param scope3PcmtSummaryId Scope3PcmtSummary record ID
     * @return List of Scope3PcmtItem records needing review
     */
    @AuraEnabled(cacheable=true)
    public static List<Scope3PcmtItem> getItemsNeedingReview(Id scope3PcmtSummaryId) {
        try {
            // Get items with no match or low confidence that haven't been reviewed yet
            List<Scope3PcmtItem> items = [
                SELECT Id, Name, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                       PcmtEmssnFctrSetItemId, PcmtEmssnFctrSetItem.Name, 
                       Match_Confidence_Score__c, Match_Reasoning__c,
                       Match_Source__c, Review_Status__c
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND (
                    PcmtEmssnFctrSetItemId = null
                    OR Match_Confidence_Score__c < 0.7
                )
                AND (Review_Status__c = 'Pending Review' OR Review_Status__c = null)
                // Note: Items with 'Passed Confidence Match' are automatically excluded by the above condition
                ORDER BY Match_Confidence_Score__c DESC NULLS LAST, Name
                LIMIT 1000
            ];
            
            return items;
            
        } catch (Exception e) {
            System.debug('Error getting items needing review: ' + e.getMessage());
            return new List<Scope3PcmtItem>();
        }
    }
    
    /**
     * @description Search for PcmtEmssnFctrSetItem records filtered by parent PcmtEmssnFctrSet
     * This method is used by the lookup field in the LWC to filter results
     * @param searchTerm Search term (searches in Name and EconomicSectorCode)
     * @param pcmtEmssnFctrSetId The parent PcmtEmssnFctrSet ID to filter by
     * @return List of matching PcmtEmssnFctrSetItem records with Id and Name
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchFactorSetItems(String searchTerm, Id pcmtEmssnFctrSetId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        
        try {
            if (pcmtEmssnFctrSetId == null) {
                return results;
            }
            
            String searchPattern = '%' + (String.isNotBlank(searchTerm) ? searchTerm : '') + '%';
            
            // Query PcmtEmssnFctrSetItem records filtered by parent and search term
            List<PcmtEmssnFctrSetItem> items = [
                SELECT Id, Name, EconomicSectorCode, EconomicSector
                FROM PcmtEmssnFctrSetItem
                WHERE PcmtEmssnFctrSetId = :pcmtEmssnFctrSetId
                AND (
                    Name LIKE :searchPattern
                    OR EconomicSectorCode LIKE :searchPattern
                    OR EconomicSector LIKE :searchPattern
                )
                ORDER BY Name
                LIMIT 50
            ];
            
            // Convert to map format for lookup field
            for (PcmtEmssnFctrSetItem item : items) {
                Map<String, Object> itemMap = new Map<String, Object>();
                itemMap.put('Id', item.Id);
                itemMap.put('Name', item.Name);
                itemMap.put('EconomicSectorCode', item.EconomicSectorCode);
                itemMap.put('EconomicSector', item.EconomicSector);
                results.add(itemMap);
            }
            
        } catch (Exception e) {
            System.debug('Error searching factor set items: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * @description Update the PcmtEmssnFctrSetItemId on a Scope3PcmtItem record
     * @param itemId Scope3PcmtItem record ID
     * @param factorSetItemId PcmtEmssnFctrSetItem record ID to link
     * @return Map with success status
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> updateItemFactorSetItem(Id itemId, Id factorSetItemId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            if (itemId == null) {
                response.put('success', false);
                response.put('error', 'Item ID is required');
                return response;
            }
            
            // Query item to get summary ID before updating
            Scope3PcmtItem itemToQuery = [
                SELECT Id, ProcurementSummaryId
                FROM Scope3PcmtItem
                WHERE Id = :itemId
                LIMIT 1
            ];
            
            Scope3PcmtItem item = new Scope3PcmtItem(Id = itemId);
            item.PcmtEmssnFctrSetItemId = factorSetItemId;
            
            update item;
            
            // Recalculate Bulk_Matching_Items_Needing_Review__c if summary exists
            if (itemToQuery.ProcurementSummaryId != null) {
                recalculateItemsNeedingReview(itemToQuery.ProcurementSummaryId);
            }
            
            response.put('success', true);
            
        } catch (Exception e) {
            response.put('success', false);
            response.put('error', 'Failed to update item: ' + e.getMessage());
            System.debug('Error updating item factor set item: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Mark an item as reviewed
     * @param itemId Scope3PcmtItem record ID
     * @param reviewStatus 'Reviewed' or 'Skipped'
     * @return Map with success status
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> markItemAsReviewed(Id itemId, String reviewStatus) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            if (itemId == null) {
                response.put('success', false);
                response.put('error', 'Item ID is required');
                return response;
            }
            
            if (reviewStatus != 'Reviewed' && reviewStatus != 'Skipped') {
                response.put('success', false);
                response.put('error', 'Review status must be "Reviewed" or "Skipped"');
                return response;
            }
            
            Scope3PcmtItem item = new Scope3PcmtItem(
                Id = itemId,
                Review_Status__c = reviewStatus
            );
            
            Database.SaveResult saveResult = Database.update(item, false);
            
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
            response.put('error', 'Failed to mark item as reviewed: ' + e.getMessage());
            System.debug('Error marking item as reviewed: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Mark multiple items as reviewed (bulk operation)
     * @param itemIds List of Scope3PcmtItem record IDs
     * @param reviewStatus 'Reviewed' or 'Skipped'
     * @return Map with success status and results
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> markItemsAsReviewed(List<Id> itemIds, String reviewStatus) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            if (itemIds == null || itemIds.isEmpty()) {
                response.put('success', false);
                response.put('error', 'Item IDs are required');
                return response;
            }
            
            if (reviewStatus != 'Reviewed' && reviewStatus != 'Skipped') {
                response.put('success', false);
                response.put('error', 'Review status must be "Reviewed" or "Skipped"');
                return response;
            }
            
            List<Scope3PcmtItem> itemsToUpdate = new List<Scope3PcmtItem>();
            for (Id itemId : itemIds) {
                itemsToUpdate.add(new Scope3PcmtItem(
                    Id = itemId,
                    Review_Status__c = reviewStatus
                ));
            }
            
            List<Database.SaveResult> saveResults = Database.update(itemsToUpdate, false);
            
            Integer successCount = 0;
            Integer failureCount = 0;
            List<String> errors = new List<String>();
            
            for (Database.SaveResult saveResult : saveResults) {
                if (saveResult.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    for (Database.Error err : saveResult.getErrors()) {
                        errors.add(err.getMessage());
                    }
                }
            }
            
            response.put('success', failureCount == 0);
            response.put('successCount', successCount);
            response.put('failureCount', failureCount);
            if (!errors.isEmpty()) {
                response.put('errors', errors);
            }
            
        } catch (Exception e) {
            response.put('success', false);
            response.put('error', 'Failed to mark items as reviewed: ' + e.getMessage());
            System.debug('Error marking items as reviewed: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Get review statistics for a Scope3PcmtSummary
     * @param scope3PcmtSummaryId Scope3PcmtSummary record ID
     * @return Map with review statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getReviewStatistics(Id scope3PcmtSummaryId) {
        Map<String, Integer> stats = new Map<String, Integer>();
        
        try {
            // Count items needing review (no match or low confidence)
            Integer totalNeedingReview = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND (
                    PcmtEmssnFctrSetItemId = null
                    OR Match_Confidence_Score__c < 0.7
                )
            ];
            
            // Count pending review
            Integer pendingReview = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND (
                    PcmtEmssnFctrSetItemId = null
                    OR Match_Confidence_Score__c < 0.7
                )
                AND (Review_Status__c = 'Pending Review' OR Review_Status__c = null)
            ];
            
            // Count reviewed
            Integer reviewed = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND Review_Status__c = 'Reviewed'
            ];
            
            // Count skipped
            Integer skipped = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND Review_Status__c = 'Skipped'
            ];
            
            stats.put('totalNeedingReview', totalNeedingReview);
            stats.put('pendingReview', pendingReview);
            stats.put('reviewed', reviewed);
            stats.put('skipped', skipped);
            
        } catch (Exception e) {
            System.debug('Error getting review statistics: ' + e.getMessage());
            stats.put('totalNeedingReview', 0);
            stats.put('pendingReview', 0);
            stats.put('reviewed', 0);
            stats.put('skipped', 0);
        }
        
        return stats;
    }
    
    /**
     * @description Recalculate and update Bulk_Matching_Items_Needing_Review__c for a Scope3PcmtSummary
     * @param summaryId Scope3PcmtSummary record ID
     */
    private static void recalculateItemsNeedingReview(Id summaryId) {
        try {
            // Count items matching the same criteria as getItemsNeedingReview
            Integer itemsNeedingReview = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :summaryId
                AND (
                    PcmtEmssnFctrSetItemId = null
                    OR Match_Confidence_Score__c < 0.7
                )
                AND (Review_Status__c = 'Pending Review' OR Review_Status__c = null)
            ];
            
            // Update the summary record
            Scope3PcmtSummary summary = new Scope3PcmtSummary(Id = summaryId);
            summary.Bulk_Matching_Items_Needing_Review__c = itemsNeedingReview;
            update summary;
            
        } catch (Exception e) {
            System.debug('Error recalculating items needing review: ' + e.getMessage());
            // Don't throw - this is a helper method that shouldn't break the main operation
        }
    }
}