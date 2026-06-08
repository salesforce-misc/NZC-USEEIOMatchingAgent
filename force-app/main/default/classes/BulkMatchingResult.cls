/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Wrapper class for bulk matching results
 * @author Your Name
 * @date 2025-01-XX
 */
public class BulkMatchingResult {
    @AuraEnabled
    public Integer totalItems { get; set; }
    
    @AuraEnabled
    public Integer processedItems { get; set; }
    
    @AuraEnabled
    public Integer successfulMatches { get; set; }
    
    @AuraEnabled
    public Integer failedMatches { get; set; }
    
    @AuraEnabled
    public List<MatchingResult> results { get; set; }
    
    @AuraEnabled
    public List<String> errors { get; set; }
    
    @AuraEnabled
    public Boolean isComplete { get; set; }
    
    @AuraEnabled
    public String status { get; set; } // 'IN_PROGRESS', 'COMPLETE', 'ERROR'
    
    /**
     * @description Default constructor
     */
    public BulkMatchingResult() {
        this.results = new List<MatchingResult>();
        this.errors = new List<String>();
        this.totalItems = 0;
        this.processedItems = 0;
        this.successfulMatches = 0;
        this.failedMatches = 0;
        this.isComplete = false;
        this.status = 'IN_PROGRESS';
    }
    
    /**
     * @description Constructor with total items
     * @param totalItems Total number of items to process
     */
    public BulkMatchingResult(Integer totalItems) {
        this();
        this.totalItems = totalItems;
    }
}
