/**
 * @description Batch Apex class for bulk matching Scope3PcmtItem records
 * @description Processes items in batches with Response Caching and Deduplication
 * @author Your Name
 * @date 2025-01-XX
 */
public class BulkMatchingBatch implements Database.Batchable<Scope3PcmtItem>, Database.Stateful {
    
    private Id scope3PcmtSummaryId;
    private Id pcmtEmssnFctrSetId; // Cached from summary
    private Scope3PcmtSummary summary; // Cached summary record
    
    // Statistics tracking
    private Integer totalProcessed = 0;
    private Integer totalMatched = 0;
    private Integer totalNeedsReview = 0;
    private Integer totalCached = 0; // Items using response cache
    private Integer totalDeduplicated = 0; // Items using deduplication
    private Integer totalLLMCalls = 0; // Actual LLM API calls made
    
    // In-memory deduplication map (persists across batch executions due to Stateful)
    private Map<String, MatchingResult> categoryHashToResult = new Map<String, MatchingResult>();
    
    // Configuration
    private static final Integer MAX_ITEMS_PER_EXECUTION = 50; // Respect 100 callout limit (50 items = max 50 callouts)
    private static final Decimal CONFIDENCE_THRESHOLD = 0.7; // Auto-apply threshold
    // Note: Batch size in executeBatch() should match MAX_ITEMS_PER_EXECUTION to ensure all items are processed
    
    /**
     * @description Constructor
     * @param summaryId Scope3PcmtSummary record ID
     */
    public BulkMatchingBatch(Id summaryId) {
        this.scope3PcmtSummaryId = summaryId;
        
        // Query and cache summary record
        List<Scope3PcmtSummary> summaries = [
            SELECT Id, PcmtEmssnFctrId
            FROM Scope3PcmtSummary
            WHERE Id = :summaryId
            LIMIT 1
        ];
        
        if (!summaries.isEmpty()) {
            this.summary = summaries[0];
            this.pcmtEmssnFctrSetId = summaries[0].PcmtEmssnFctrId;
        }
    }
    
    /**
     * @description Start method - returns iterable of items to process
     * @param bc Batch context
     * @return Iterable of Scope3PcmtItem records
     */
    public Iterable<Scope3PcmtItem> start(Database.BatchableContext bc) {
        // Query all unmatched items for this summary
        return [
            SELECT Id, SpendingCategory1, SpendingCategory2, SpendingCategory3,
                   ProcurementSummaryId, PcmtEmssnFctrSetItemId
            FROM Scope3PcmtItem
            WHERE ProcurementSummaryId = :scope3PcmtSummaryId
            AND PcmtEmssnFctrSetItemId = null // Only unmatched items
            ORDER BY Id
        ];
    }
    
    /**
     * @description Execute method - processes batch of items
     * @param bc Batch context
     * @param items List of Scope3PcmtItem records to process
     */
    public void execute(Database.BatchableContext bc, List<Scope3PcmtItem> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        
        if (pcmtEmssnFctrSetId == null) {
            System.debug('ERROR: PcmtEmssnFctrSetId is null. Cannot process items.');
            return;
        }
        
        List<Scope3PcmtItem> itemsToUpdate = new List<Scope3PcmtItem>();
        Integer itemsProcessedInBatch = 0;
        
        // Process items (respecting callout limits)
        for (Scope3PcmtItem item : items) {
            // Check governor limits
            if (Limits.getCallouts() >= 90) {
                System.debug('Approaching callout limit. Stopping batch execution. Processed ' + itemsProcessedInBatch + ' items.');
                break;
            }
            
            if (Limits.getCpuTime() >= 9000) {
                System.debug('Approaching CPU time limit. Stopping batch execution. Processed ' + itemsProcessedInBatch + ' items.');
                break;
            }
            
            // Limit items per execution to respect callout limits
            if (itemsProcessedInBatch >= MAX_ITEMS_PER_EXECUTION) {
                System.debug('Reached max items per execution limit. Processed ' + itemsProcessedInBatch + ' items.');
                break;
            }
            
            try {
                // Generate category hash for deduplication
                String categoryHash = generateCategoryHash(
                    item.SpendingCategory1,
                    item.SpendingCategory2,
                    item.SpendingCategory3
                );
                
                MatchingResult result = null;
                Boolean fromDeduplication = false;
                Boolean fromCache = false;
                
                // Step 1: Check Deduplication Map (Memory) - FASTEST
                if (categoryHashToResult.containsKey(categoryHash)) {
                    // Found in memory - reuse result
                    MatchingResult cachedResult = categoryHashToResult.get(categoryHash);
                    result = cloneMatchingResult(cachedResult, item.Id);
                    fromDeduplication = true;
                    totalDeduplicated++;
                    System.debug('Deduplication hit for item: ' + item.Id);
                }
                
                // Step 2: Check Response Cache (Database) - if not found in deduplication map
                if (result == null) {
                    try {
                        LLMService.LLMResponse cachedResponse = LLMResponseCache.getCachedResponse(
                            item.SpendingCategory1,
                            item.SpendingCategory2,
                            item.SpendingCategory3,
                            pcmtEmssnFctrSetId
                        );
                        
                        if (cachedResponse != null && String.isNotBlank(cachedResponse.suggestedNaicsCode)) {
                            // Found in cache - build result from cache
                            result = buildMatchingResultFromCache(cachedResponse, item, pcmtEmssnFctrSetId);
                            
                            if (result != null) {
                                // Store in deduplication map for future items in this batch
                                categoryHashToResult.put(categoryHash, result);
                                fromCache = true;
                                totalCached++;
                                System.debug('Cache hit for item: ' + item.Id);
                            }
                        }
                    } catch (Exception cacheEx) {
                        // If cache lookup fails, log and continue with LLM call
                        System.debug('Cache lookup failed (continuing with LLM): ' + cacheEx.getMessage());
                    }
                }
                
                // Step 3: Call LLM (if not found in deduplication map or cache)
                if (result == null) {
                    // Call the matching service (which will handle LLM call and cache save)
                    result = USEEIOMatchingService.matchSpendItemToFactorInternal(item, summary);
                    totalLLMCalls++;
                    
                    // Store in deduplication map for future items in this batch
                    if (result != null) {
                        categoryHashToResult.put(categoryHash, result);
                        System.debug('LLM call made for item: ' + item.Id);
                    }
                }
                
                // Step 4: Process result
                if (result != null) {
                    // Auto-apply high confidence matches
                    if (result.status == 'MATCHED' && result.confidenceScore >= CONFIDENCE_THRESHOLD) {
                        item.PcmtEmssnFctrSetItemId = result.recommendedFactorId;
                        item.Match_Confidence_Score__c = result.confidenceScore;
                        item.Match_Reasoning__c = result.reasoning;
                        item.Match_Source__c = 'AI Suggested';
                        itemsToUpdate.add(item);
                        totalMatched++;
                    } else {
                        // Low confidence or no match - needs review
                        item.Review_Status__c = 'Pending Review';
                        itemsToUpdate.add(item);
                        totalNeedsReview++;
                    }
                } else {
                    // No result - needs review
                    item.Review_Status__c = 'Pending Review';
                    itemsToUpdate.add(item);
                    totalNeedsReview++;
                }
                
                totalProcessed++;
                itemsProcessedInBatch++;
                
            } catch (Exception e) {
                // Log error but continue processing other items
                System.debug('Error processing item ' + item.Id + ': ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                totalNeedsReview++;
                totalProcessed++;
            }
        }
        
        // Batch update items
        if (!itemsToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] saveResults = Database.update(itemsToUpdate, false);
                
                // Log any failures
                for (Integer i = 0; i < saveResults.size(); i++) {
                    if (!saveResults[i].isSuccess()) {
                        System.debug('Failed to update item ' + itemsToUpdate[i].Id + ': ' + saveResults[i].getErrors());
                    }
                }
            } catch (Exception updateEx) {
                System.debug('Error updating items: ' + updateEx.getMessage());
            }
        }
    }
    
    /**
     * @description Finish method - updates summary with final statistics
     * @param bc Batch context
     */
    public void finish(Database.BatchableContext bc) {
        try {
            // Query summary to update
            Scope3PcmtSummary summaryToUpdate = [
                SELECT Id, Bulk_Matching_Status__c, Bulk_Matching_Completed_Date__c,
                       Bulk_Matching_Items_Processed__c, Bulk_Matching_Items_Matched__c,
                       Bulk_Matching_Items_Needing_Review__c, Bulk_Matching_Cache_Hits__c,
                       Bulk_Matching_Deduplicated__c, Bulk_Matching_LLM_Calls__c,
                       Bulk_Matching_Cost_Saved__c
                FROM Scope3PcmtSummary
                WHERE Id = :scope3PcmtSummaryId
                LIMIT 1
            ];
            
            // Update statistics
            summaryToUpdate.Bulk_Matching_Status__c = 'Complete';
            summaryToUpdate.Bulk_Matching_Completed_Date__c = DateTime.now();
            summaryToUpdate.Bulk_Matching_Items_Processed__c = totalProcessed;
            summaryToUpdate.Bulk_Matching_Items_Matched__c = totalMatched;
            summaryToUpdate.Bulk_Matching_Items_Needing_Review__c = totalNeedsReview;
            summaryToUpdate.Bulk_Matching_Cache_Hits__c = totalCached;
            summaryToUpdate.Bulk_Matching_Deduplicated__c = totalDeduplicated;
            summaryToUpdate.Bulk_Matching_LLM_Calls__c = totalLLMCalls;
            
            // Calculate cost savings (Cache hits + Deduplicated) × $0.0225 per call
            Decimal costPerCall = 0.0225;
            Decimal costSaved = (Decimal.valueOf(totalCached) + Decimal.valueOf(totalDeduplicated)) * costPerCall;
            summaryToUpdate.Bulk_Matching_Cost_Saved__c = costSaved;
            
            update summaryToUpdate;
            
            System.debug('Bulk matching completed. Processed: ' + totalProcessed + 
                        ', Matched: ' + totalMatched + 
                        ', Needs Review: ' + totalNeedsReview +
                        ', Cache Hits: ' + totalCached +
                        ', Deduplicated: ' + totalDeduplicated +
                        ', LLM Calls: ' + totalLLMCalls +
                        ', Cost Saved: $' + costSaved);
            
        } catch (Exception e) {
            System.debug('Error updating summary in finish method: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Try to update status to Error
            try {
                Scope3PcmtSummary summaryError = [
                    SELECT Id, Bulk_Matching_Status__c
                    FROM Scope3PcmtSummary
                    WHERE Id = :scope3PcmtSummaryId
                    LIMIT 1
                ];
                summaryError.Bulk_Matching_Status__c = 'Error';
                update summaryError;
            } catch (Exception updateEx) {
                System.debug('Failed to update error status: ' + updateEx.getMessage());
            }
        }
    }
    
    /**
     * @description Generate hash for category combination (same as LLMResponseCache)
     * @param cat1 First spending category
     * @param cat2 Second spending category
     * @param cat3 Third spending category
     * @return SHA-256 hash as base64 string
     */
    private String generateCategoryHash(String cat1, String cat2, String cat3) {
        String combined = (cat1 != null ? cat1.toLowerCase().trim() : '') + '|' +
                          (cat2 != null ? cat2.toLowerCase().trim() : '') + '|' +
                          (cat3 != null ? cat3.toLowerCase().trim() : '');
        return EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(combined)));
    }
    
    /**
     * @description Clone MatchingResult for a different item ID
     * @param original Original MatchingResult
     * @param newItemId New Scope3PcmtItem ID
     * @return Cloned MatchingResult
     */
    private MatchingResult cloneMatchingResult(MatchingResult original, Id newItemId) {
        MatchingResult clone = new MatchingResult(newItemId, original.status);
        clone.recommendedFactorId = original.recommendedFactorId;
        clone.recommendedNaicsCode = original.recommendedNaicsCode;
        clone.recommendedEconomicSector = original.recommendedEconomicSector;
        clone.emissionsFactorValue = original.emissionsFactorValue;
        clone.confidenceScore = original.confidenceScore;
        clone.reasoning = original.reasoning;
        clone.errorMessage = original.errorMessage;
        
        // Clone alternatives
        if (original.alternatives != null) {
            clone.alternatives = new List<AlternativeMatch>();
            for (AlternativeMatch alt : original.alternatives) {
                clone.alternatives.add(alt);
            }
        }
        
        return clone;
    }
    
    /**
     * @description Build MatchingResult from cached LLM response
     * @param cachedResponse Cached LLM response
     * @param item Scope3PcmtItem record
     * @param pcmtEmssnFctrSetId Factor set ID
     * @return MatchingResult
     */
    private MatchingResult buildMatchingResultFromCache(
        LLMService.LLMResponse cachedResponse,
        Scope3PcmtItem item,
        Id pcmtEmssnFctrSetId
    ) {
        MatchingResult result = new MatchingResult(item.Id, 'NO_MATCH');
        
        if (String.isBlank(cachedResponse.suggestedNaicsCode)) {
            result.errorMessage = 'Cached response has no NAICS code';
            return result;
        }
        
        // Validate NAICS code format
        if (!LLMService.validateNaicsCode(cachedResponse.suggestedNaicsCode)) {
            result.errorMessage = 'Invalid NAICS code in cache: ' + cachedResponse.suggestedNaicsCode;
            return result;
        }
        
        // Find matching factors
        List<PcmtEmssnFctrSetItem> matchingFactors = USEEIOMatchingService.findMatchingFactors(
            cachedResponse.suggestedNaicsCode,
            pcmtEmssnFctrSetId
        );
        
        if (matchingFactors.isEmpty()) {
            result.errorMessage = 'No matching emissions factor found for cached NAICS code: ' + cachedResponse.suggestedNaicsCode;
            result.reasoning = cachedResponse.reasoning;
            return result;
        }
        
        // Calculate confidence score
        Decimal confidenceScore = USEEIOMatchingService.calculateConfidenceScore(
            cachedResponse.suggestedNaicsCode,
            matchingFactors,
            cachedResponse.confidence
        );
        
        // Build result
        PcmtEmssnFctrSetItem recommendedFactor = matchingFactors[0];
        result.recommendedFactorId = recommendedFactor.Id;
        result.recommendedNaicsCode = cachedResponse.suggestedNaicsCode;
        result.recommendedEconomicSector = recommendedFactor.EconomicSector;
        result.emissionsFactorValue = recommendedFactor.TotScpe3EmssnPerMillionSpent;
        result.confidenceScore = confidenceScore;
        result.reasoning = cachedResponse.reasoning;
        result.status = confidenceScore >= CONFIDENCE_THRESHOLD ? 'MATCHED' : 'REQUIRES_REVIEW';
        
        // Add alternatives if available
        if (cachedResponse.alternativeNaicsCodes != null && !cachedResponse.alternativeNaicsCodes.isEmpty()) {
            result.alternatives = new List<AlternativeMatch>();
            for (String altNaics : cachedResponse.alternativeNaicsCodes) {
                if (LLMService.validateNaicsCode(altNaics)) {
                    List<PcmtEmssnFctrSetItem> altFactors = USEEIOMatchingService.findMatchingFactors(altNaics, pcmtEmssnFctrSetId);
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
        
        return result;
    }
}
