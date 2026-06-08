/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Service class for caching LLM responses to reduce API costs
 * @description Stores responses in custom object LLM_Response_Cache__c for persistent cross-session caching
 * @author Your Name
 * @date 2025-01-XX
 */
public class LLMResponseCache {
    
    /**
     * @description Generate hash for category combination
     * @param cat1 First spending category
     * @param cat2 Second spending category
     * @param cat3 Third spending category
     * @return SHA-256 hash as base64 string
     */
    private static String generateHash(String cat1, String cat2, String cat3) {
        String combined = (cat1 != null ? cat1.toLowerCase().trim() : '') + '|' +
                          (cat2 != null ? cat2.toLowerCase().trim() : '') + '|' +
                          (cat3 != null ? cat3.toLowerCase().trim() : '');
        return EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(combined)));
    }
    
    /**
     * @description Get cached LLM response for category combination
     * @param cat1 First spending category
     * @param cat2 Second spending category
     * @param cat3 Third spending category
     * @param pcmtEmssnFctrSetId Factor set ID (for cache key)
     * @return LLMResponse if found in cache, null otherwise
     */
    public static LLMService.LLMResponse getCachedResponse(
        String cat1,
        String cat2,
        String cat3,
        Id pcmtEmssnFctrSetId
    ) {
        String hash = generateHash(cat1, cat2, cat3);
        
        // Query cache with hash and factor set
        List<LLM_Response_Cache__c> cached = [
            SELECT Suggested_NAICS__c, Confidence__c, Reasoning__c,
                   Alternative_NAICS_Codes__c, Last_Used_Date__c, Use_Count__c
            FROM LLM_Response_Cache__c
            WHERE Category_Hash__c = :hash
            AND Factor_Set_ID__c = :pcmtEmssnFctrSetId
            LIMIT 1
        ];
        
        if (!cached.isEmpty()) {
            LLM_Response_Cache__c cache = cached[0];
            
            // Update usage tracking
            cache.Last_Used_Date__c = DateTime.now();
            cache.Use_Count__c = (cache.Use_Count__c != null ? cache.Use_Count__c : 0) + 1;
            update cache;
            
            // Build and return LLMResponse
            return buildResponseFromCache(cache);
        }
        
        return null;
    }
    
    /**
     * @description Save LLM response to cache
     * @param cat1 First spending category
     * @param cat2 Second spending category
     * @param cat3 Third spending category
     * @param pcmtEmssnFctrSetId Factor set ID
     * @param response LLM response to cache
     */
    public static void saveResponse(
        String cat1,
        String cat2,
        String cat3,
        Id pcmtEmssnFctrSetId,
        LLMService.LLMResponse response
    ) {
        if (response == null || String.isBlank(response.suggestedNaicsCode)) {
            return; // Don't cache invalid responses
        }
        
        String hash = generateHash(cat1, cat2, cat3);
        
        // Check if cache entry already exists (upsert pattern)
        List<LLM_Response_Cache__c> existing = [
            SELECT Id
            FROM LLM_Response_Cache__c
            WHERE Category_Hash__c = :hash
            AND Factor_Set_ID__c = :pcmtEmssnFctrSetId
            LIMIT 1
        ];
        
        LLM_Response_Cache__c cache;
        if (!existing.isEmpty()) {
            cache = existing[0];
        } else {
            cache = new LLM_Response_Cache__c();
            cache.Category_Hash__c = hash;
            cache.Factor_Set_ID__c = pcmtEmssnFctrSetId;
            cache.Use_Count__c = 0;
        }
        
        // Update cache fields
        cache.Suggested_NAICS__c = response.suggestedNaicsCode;
        cache.Confidence__c = response.confidence;
        cache.Reasoning__c = response.reasoning;
        
        // Store alternative codes as comma-separated string
        if (response.alternativeNaicsCodes != null && !response.alternativeNaicsCodes.isEmpty()) {
            cache.Alternative_NAICS_Codes__c = String.join(response.alternativeNaicsCodes, ',');
        }
        
        if (cache.Id == null) {
            cache.Created_Date__c = DateTime.now();
            insert cache;
        } else {
            update cache;
        }
    }
    
    /**
     * @description Build LLMResponse from cache record
     * @param cache Cache record
     * @return LLMResponse object
     */
    private static LLMService.LLMResponse buildResponseFromCache(LLM_Response_Cache__c cache) {
        LLMService.LLMResponse response = new LLMService.LLMResponse();
        response.suggestedNaicsCode = cache.Suggested_NAICS__c;
        response.confidence = cache.Confidence__c;
        response.reasoning = cache.Reasoning__c;
        
        // Parse alternative codes
        if (String.isNotBlank(cache.Alternative_NAICS_Codes__c)) {
            response.alternativeNaicsCodes = cache.Alternative_NAICS_Codes__c.split(',');
        }
        
        return response;
    }
    
    /**
     * @description Clear cache entries for a specific factor set
     * @param pcmtEmssnFctrSetId Factor set ID
     * @return Number of records deleted
     */
    public static Integer clearCacheForFactorSet(Id pcmtEmssnFctrSetId) {
        List<LLM_Response_Cache__c> toDelete = [
            SELECT Id
            FROM LLM_Response_Cache__c
            WHERE Factor_Set_ID__c = :pcmtEmssnFctrSetId
        ];
        
        Integer count = toDelete.size();
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        
        return count;
    }
    
    /**
     * @description Get cache statistics
     * @param pcmtEmssnFctrSetId Factor set ID (optional, null for all)
     * @return Map with statistics
     */
    public static Map<String, Integer> getCacheStatistics(Id pcmtEmssnFctrSetId) {
        String query = 'SELECT COUNT() total, SUM(Use_Count__c) totalUses FROM LLM_Response_Cache__c';
        if (pcmtEmssnFctrSetId != null) {
            query += ' WHERE Factor_Set_ID__c = :pcmtEmssnFctrSetId';
        }
        
        // Note: Aggregate queries return AggregateResult, simplified here
        Integer totalEntries = Database.countQuery('SELECT COUNT() FROM LLM_Response_Cache__c' + 
            (pcmtEmssnFctrSetId != null ? ' WHERE Factor_Set_ID__c = :pcmtEmssnFctrSetId' : ''));
        
        Map<String, Integer> stats = new Map<String, Integer>();
        stats.put('totalEntries', totalEntries);
        
        return stats;
    }
}
