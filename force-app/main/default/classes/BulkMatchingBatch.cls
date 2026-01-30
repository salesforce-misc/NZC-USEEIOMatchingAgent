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
    // Reduced batch size to ensure we stay well under CPU limits (60 seconds for Batch Apex)
    // With 25 items, we can process ~2-3 items per second and stay under 60 seconds
    // This allows processing tens of thousands of items across multiple batch executions
    private static final Integer MAX_ITEMS_PER_EXECUTION = 25; // Conservative limit to avoid CPU timeouts
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
        // #region agent log
        System.debug('[DEBUG] BulkMatchingBatch.execute - ENTRY: items.size=' + (items != null ? items.size() : 0) + ', totalProcessed=' + totalProcessed + ', batchJobId=' + bc.getJobId());
        // #endregion
        
        if (items == null || items.isEmpty()) {
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.execute - EXIT: No items to process');
            // #endregion
            return;
        }
        
        if (pcmtEmssnFctrSetId == null) {
            System.debug('ERROR: PcmtEmssnFctrSetId is null. Cannot process items.');
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.execute - ERROR: pcmtEmssnFctrSetId is null');
            // #endregion
            return;
        }
        
        // Separate lists for results and items to update
        Map<Id, MatchingResult> itemResults = new Map<Id, MatchingResult>();
        List<Scope3PcmtItem> itemsToUpdate = new List<Scope3PcmtItem>();
        // Cache entries to save after all callouts are done
        List<CacheEntry> cacheEntriesToSave = new List<CacheEntry>();
        Integer itemsProcessedInBatch = 0;
        
        System.debug('Starting batch execution with ' + items.size() + ' items. Current callouts: ' + Limits.getCallouts() + ', CPU time: ' + Limits.getCpuTime());
        
        // #region agent log
        System.debug('[DEBUG] BulkMatchingBatch.execute - BEFORE PROCESSING: totalProcessed=' + totalProcessed + ', itemsInThisBatch=' + items.size() + ', summaryId=' + scope3PcmtSummaryId);
        // #endregion
        
        // PHASE 1: Make all LLM calls first (no DML operations)
        for (Scope3PcmtItem item : items) {
            System.debug('Processing item ' + (itemsProcessedInBatch + 1) + ' of ' + items.size() + ': ' + item.Id);
            
            // Check governor limits
            if (Limits.getCallouts() >= 90) {
                System.debug('Approaching callout limit (' + Limits.getCallouts() + '). Stopping batch execution. Processed ' + itemsProcessedInBatch + ' items.');
                break;
            }
            
            // Limit items per execution to respect callout limits and CPU time
            // This ensures we don't process too many items in a single execution
            if (itemsProcessedInBatch >= MAX_ITEMS_PER_EXECUTION) {
                System.debug('Reached max items per execution limit (' + MAX_ITEMS_PER_EXECUTION + '). Processed ' + itemsProcessedInBatch + ' items.');
                break;
            }
            
            // Safety check: Stop if approaching CPU time limit (Batch Apex has 60 seconds)
            // This should rarely trigger with MAX_ITEMS_PER_EXECUTION = 25, but provides safety net
            if (Limits.getCpuTime() >= 55000) {
                System.debug('WARNING: Approaching CPU time limit (' + Limits.getCpuTime() + '). Stopping batch execution. Processed ' + itemsProcessedInBatch + ' items.');
                System.debug('Consider reducing MAX_ITEMS_PER_EXECUTION if this occurs frequently.');
                break;
            }
            
            try {
                System.debug('Starting try block for item: ' + item.Id);
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
                // NOTE: We skip cache updates during callout phase to avoid pending DML
                // Cache updates will be handled after all callouts are complete
                if (result == null) {
                    try {
                        // Query cache without updating (to avoid pending DML)
                        String hash = generateCategoryHash(
                            item.SpendingCategory1,
                            item.SpendingCategory2,
                            item.SpendingCategory3
                        );
                        List<LLM_Response_Cache__c> cached = [
                            SELECT Suggested_NAICS__c, Confidence__c, Reasoning__c,
                                   Alternative_NAICS_Codes__c
                            FROM LLM_Response_Cache__c
                            WHERE Category_Hash__c = :hash
                            AND Factor_Set_ID__c = :pcmtEmssnFctrSetId
                            LIMIT 1
                        ];
                        
                        if (!cached.isEmpty()) {
                            LLM_Response_Cache__c cache = cached[0];
                            // Build LLMResponse from cache (without updating usage stats)
                            LLMService.LLMResponse cachedResponse = new LLMService.LLMResponse();
                            cachedResponse.suggestedNaicsCode = cache.Suggested_NAICS__c;
                            cachedResponse.confidence = cache.Confidence__c;
                            cachedResponse.reasoning = cache.Reasoning__c;
                            if (String.isNotBlank(cache.Alternative_NAICS_Codes__c)) {
                                cachedResponse.alternativeNaicsCodes = cache.Alternative_NAICS_Codes__c.split(',');
                            }
                            
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
                        }
                    } catch (Exception cacheEx) {
                        // If cache lookup fails, log and continue with LLM call
                        System.debug('Cache lookup failed (continuing with LLM): ' + cacheEx.getMessage());
                    }
                }
                
                // Step 3: Call LLM (if not found in deduplication map or cache)
                if (result == null) {
                    System.debug('Calling LLM for item: ' + item.Id + ', Categories: ' + 
                                item.SpendingCategory1 + ' | ' + item.SpendingCategory2 + ' | ' + item.SpendingCategory3);
                    // Call the matching service (cache save is deferred to avoid pending DML)
                    result = USEEIOMatchingService.matchSpendItemToFactorInternal(item, summary);
                    totalLLMCalls++;
                    
                    if (result != null) {
                        System.debug('LLM result for item ' + item.Id + ': status=' + result.status + 
                                    ', confidence=' + result.confidenceScore + 
                                    ', error=' + result.errorMessage);
                        
                        // Collect cache entry to save later (after all callouts)
                        if (result.status == 'MATCHED' || result.status == 'REQUIRES_REVIEW') {
                            // Get the LLM response from the result to save to cache
                            // We'll need to reconstruct it from the result
                            LLMService.LLMResponse llmResponseToCache = new LLMService.LLMResponse();
                            llmResponseToCache.suggestedNaicsCode = result.recommendedNaicsCode;
                            llmResponseToCache.confidence = result.confidenceScore >= 0.7 ? 'HIGH' : 
                                                           (result.confidenceScore >= 0.5 ? 'MEDIUM' : 'LOW');
                            llmResponseToCache.reasoning = result.reasoning;
                            
                            // Store cache entry info for later save
                            CacheEntry cacheEntry = new CacheEntry();
                            cacheEntry.cat1 = item.SpendingCategory1;
                            cacheEntry.cat2 = item.SpendingCategory2;
                            cacheEntry.cat3 = item.SpendingCategory3;
                            cacheEntry.factorSetId = pcmtEmssnFctrSetId;
                            cacheEntry.response = llmResponseToCache;
                            cacheEntriesToSave.add(cacheEntry);
                        }
                    } else {
                        System.debug('LLM result for item ' + item.Id + ': result is null');
                    }
                    
                    // Store in deduplication map for future items in this batch
                    if (result != null) {
                        categoryHashToResult.put(categoryHash, result);
                        System.debug('LLM call made for item: ' + item.Id);
                    } else {
                        System.debug('ERROR: LLM result is null for item: ' + item.Id);
                    }
                }
                
                // Step 4: Store result for later processing (don't update item yet - avoid pending DML)
                if (result != null) {
                    itemResults.put(item.Id, result);
                } else {
                    // Create a NO_MATCH result for items with no result
                    MatchingResult noMatchResult = new MatchingResult(item.Id, 'NO_MATCH');
                    noMatchResult.errorMessage = 'No matching result returned';
                    itemResults.put(item.Id, noMatchResult);
                }
                
                totalProcessed++;
                itemsProcessedInBatch++;
                System.debug('Successfully processed item ' + item.Id + '. Total processed in batch: ' + itemsProcessedInBatch);
                
                // #region agent log
                System.debug('[DEBUG] BulkMatchingBatch.execute - ITEM PROCESSED: itemId=' + item.Id + ', itemsProcessedInBatch=' + itemsProcessedInBatch + ', totalProcessed=' + totalProcessed);
                // #endregion
                
            } catch (Exception e) {
                // Log error but continue processing other items
                System.debug('Error processing item ' + item.Id + ': ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                totalNeedsReview++;
                totalProcessed++;
            }
        }
        
        // PHASE 2: Save cache entries (all callouts are done, safe to do DML)
        System.debug('All LLM calls completed. Saving ' + cacheEntriesToSave.size() + ' cache entries.');
        for (CacheEntry cacheEntry : cacheEntriesToSave) {
            try {
                LLMResponseCache.saveResponse(
                    cacheEntry.cat1,
                    cacheEntry.cat2,
                    cacheEntry.cat3,
                    cacheEntry.factorSetId,
                    cacheEntry.response
                );
            } catch (Exception cacheEx) {
                System.debug('Failed to save cache entry: ' + cacheEx.getMessage());
            }
        }
        
        // PHASE 3: Now update all items based on results (all callouts and cache saves are done)
        System.debug('All cache saves completed. Now updating ' + itemResults.size() + ' items.');
        for (Scope3PcmtItem item : items) {
            MatchingResult result = itemResults.get(item.Id);
            if (result == null) {
                // No result - needs review
                System.debug('No result for item: ' + item.Id + ' - marking for review');
                item.Review_Status__c = 'Pending Review';
                itemsToUpdate.add(item);
                totalNeedsReview++;
                continue;
            }
            
            System.debug('Processing result for item ' + item.Id + ': status=' + result.status + 
                        ', confidence=' + result.confidenceScore + ', threshold=' + CONFIDENCE_THRESHOLD);
            
            // Auto-apply high confidence matches
            if (result.status == 'MATCHED' && result.confidenceScore >= CONFIDENCE_THRESHOLD) {
                System.debug('Auto-matching item ' + item.Id + ' with confidence ' + result.confidenceScore);
                item.PcmtEmssnFctrSetItemId = result.recommendedFactorId;
                item.Match_Confidence_Score__c = result.confidenceScore;
                item.Match_Reasoning__c = result.reasoning;
                item.Match_Source__c = 'AI Suggested';
                item.Review_Status__c = 'Passed Confidence Match'; // Mark as passed - no manual review needed
                itemsToUpdate.add(item);
                totalMatched++;
            } else {
                // Low confidence or no match - needs review
                System.debug('Item ' + item.Id + ' needs review: status=' + result.status + 
                            ', confidence=' + result.confidenceScore + 
                            ', error=' + result.errorMessage);
                item.Review_Status__c = 'Pending Review';
                // Still save confidence and reasoning if available
                if (result.confidenceScore != null) {
                    item.Match_Confidence_Score__c = result.confidenceScore;
                }
                if (String.isNotBlank(result.reasoning)) {
                    item.Match_Reasoning__c = result.reasoning;
                }
                itemsToUpdate.add(item);
                totalNeedsReview++;
            }
        }
        
        // Batch update items (all callouts and cache saves are done, safe to do DML)
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
        
        // #region agent log
        System.debug('[DEBUG] BulkMatchingBatch.execute - AFTER PROCESSING: itemsProcessedInBatch=' + itemsProcessedInBatch + ', totalProcessed=' + totalProcessed + ', totalMatched=' + totalMatched + ', totalNeedsReview=' + totalNeedsReview);
        // #endregion
        
        // Update summary record incrementally during execution (not just at finish)
        // This allows the UI to see progress in real-time
        try {
            Scope3PcmtSummary summaryToUpdate = [
                SELECT Id, Bulk_Matching_Items_Processed__c, Bulk_Matching_Items_Matched__c,
                       Bulk_Matching_Items_Needing_Review__c, Bulk_Matching_Cache_Hits__c,
                       Bulk_Matching_Deduplicated__c, Bulk_Matching_LLM_Calls__c
                FROM Scope3PcmtSummary
                WHERE Id = :scope3PcmtSummaryId
                LIMIT 1
            ];
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.execute - BEFORE UPDATE: currentProcessed=' + summaryToUpdate.Bulk_Matching_Items_Processed__c + ', newTotalProcessed=' + totalProcessed);
            // #endregion
            
            summaryToUpdate.Bulk_Matching_Items_Processed__c = totalProcessed;
            summaryToUpdate.Bulk_Matching_Items_Matched__c = totalMatched;
            summaryToUpdate.Bulk_Matching_Items_Needing_Review__c = totalNeedsReview;
            summaryToUpdate.Bulk_Matching_Cache_Hits__c = totalCached;
            summaryToUpdate.Bulk_Matching_Deduplicated__c = totalDeduplicated;
            summaryToUpdate.Bulk_Matching_LLM_Calls__c = totalLLMCalls;
            
            update summaryToUpdate;
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.execute - AFTER UPDATE: updatedProcessed=' + summaryToUpdate.Bulk_Matching_Items_Processed__c + ', updatedMatched=' + summaryToUpdate.Bulk_Matching_Items_Matched__c);
            // #endregion
        } catch (Exception updateEx) {
            System.debug('Error updating summary during execution: ' + updateEx.getMessage());
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.execute - UPDATE ERROR: ' + updateEx.getMessage());
            // #endregion
        }
    }
    
    /**
     * @description Finish method - updates summary with final statistics
     * @param bc Batch context
     */
    public void finish(Database.BatchableContext bc) {
        // #region agent log
        System.debug('[DEBUG] BulkMatchingBatch.finish - ENTRY: totalProcessed=' + totalProcessed + ', totalMatched=' + totalMatched + ', totalNeedsReview=' + totalNeedsReview + ', batchJobId=' + bc.getJobId());
        // #endregion
        
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
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.finish - BEFORE UPDATE: currentProcessed=' + summaryToUpdate.Bulk_Matching_Items_Processed__c + ', currentMatched=' + summaryToUpdate.Bulk_Matching_Items_Matched__c);
            // #endregion
            
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
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingBatch.finish - AFTER UPDATE: updatedProcessed=' + summaryToUpdate.Bulk_Matching_Items_Processed__c + ', updatedMatched=' + summaryToUpdate.Bulk_Matching_Items_Matched__c + ', updatedNeedsReview=' + summaryToUpdate.Bulk_Matching_Items_Needing_Review__c);
            // #endregion
            
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
     * @description Inner class to hold cache entry information for deferred saving
     */
    private class CacheEntry {
        String cat1;
        String cat2;
        String cat3;
        Id factorSetId;
        LLMService.LLMResponse response;
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
            // Enhanced EEIO detection: check sector range AND existence in other factor sets
            Boolean isEeioCode = USEEIOMatchingService.isLikelyEeioCode(
                cachedResponse.suggestedNaicsCode,
                cachedResponse.confidence,
                pcmtEmssnFctrSetId  // Pass the linked factor set ID
            );
            
            if (isEeioCode) {
                // Determine the specific reason for EEIO detection
                String sectorStr = cachedResponse.suggestedNaicsCode.substring(0, 2);
                Integer sector = Integer.valueOf(sectorStr);
                Boolean isOutsideRange = sector < 11 || sector > 92;
                Boolean existsInOtherFactorSet = USEEIOMatchingService.codeExistsInOtherFactorSet(
                    cachedResponse.suggestedNaicsCode,
                    pcmtEmssnFctrSetId
                );
                
                if (isOutsideRange) {
                    // Original case: sector outside NAICS range
                    result.errorMessage = 'Cached response contains code ' + cachedResponse.suggestedNaicsCode + 
                        ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                        'This code is not available in the selected emissions factor set, which uses NAICS codes. ' +
                        'The LLM reasoning is preserved for reference.';
                    result.reasoning = cachedResponse.reasoning + 
                        '\n\n[Note: The LLM identified an EEIO code (' + cachedResponse.suggestedNaicsCode + 
                        ') instead of a NAICS code. Please review the spending categories and select an appropriate NAICS code from the factor set.]';
                } else if (existsInOtherFactorSet && cachedResponse.confidence == 'HIGH') {
                    // New case: code exists in other factor sets but not in linked NAICS factor set
                    result.errorMessage = 'Cached response contains code ' + cachedResponse.suggestedNaicsCode + 
                        ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                        'While this code follows NAICS format, it exists in other emissions factor sets in the system but not in the selected factor set (which contains NAICS codes). ' +
                        'The LLM was highly confident in this match, suggesting it may have identified an EEIO code. ' +
                        'Please review the spending categories and select an appropriate NAICS code from the selected factor set.';
                    result.reasoning = cachedResponse.reasoning + 
                        '\n\n[Note: The LLM identified code ' + cachedResponse.suggestedNaicsCode + 
                        ' with HIGH confidence. This code exists in other emissions factor sets but not in the selected factor set (which contains NAICS codes). ' +
                        'This suggests the LLM may have identified an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                        'Please review the spending categories and select an appropriate NAICS code from the selected factor set.]';
                } else {
                    // Fallback to original message
                    result.errorMessage = 'Cached response contains code ' + cachedResponse.suggestedNaicsCode + 
                        ', which appears to be an EEIO (Economic Input-Output) code rather than a NAICS code. ' +
                        'This code is not available in the selected emissions factor set, which uses NAICS codes.';
                    result.reasoning = cachedResponse.reasoning + 
                        '\n\n[Note: The LLM identified an EEIO code (' + cachedResponse.suggestedNaicsCode + 
                        ') instead of a NAICS code. Please review the spending categories and select an appropriate NAICS code from the factor set.]';
                }
            } else {
                // Valid NAICS code format but not in factor set
                result.errorMessage = 'No matching emissions factor found for cached NAICS code: ' + cachedResponse.suggestedNaicsCode;
                result.reasoning = cachedResponse.reasoning;
            }
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
