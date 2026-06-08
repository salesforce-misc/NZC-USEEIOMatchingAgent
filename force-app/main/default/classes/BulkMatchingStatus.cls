/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Wrapper class for bulk matching status (for LWC polling)
 * @author Your Name
 * @date 2025-01-XX
 */
public class BulkMatchingStatus {
    @AuraEnabled
    public String status { get; set; } // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETE', 'ERROR'
    
    @AuraEnabled
    public Integer totalItems { get; set; }
    
    @AuraEnabled
    public Integer processedItems { get; set; }
    
    @AuraEnabled
    public Integer matchedItems { get; set; }
    
    @AuraEnabled
    public Integer needsReviewItems { get; set; }
    
    @AuraEnabled
    public String jobId { get; set; }
    
    @AuraEnabled
    public DateTime completedDate { get; set; }
    
    @AuraEnabled
    public String errorMessage { get; set; }
    
    @AuraEnabled
    public Decimal progressPercentage { get; set; }
    
    @AuraEnabled
    public Integer cacheHits { get; set; }
    
    @AuraEnabled
    public Integer deduplicated { get; set; }
    
    @AuraEnabled
    public Integer llmCalls { get; set; }
    
    @AuraEnabled
    public Decimal costSaved { get; set; }
    
    @AuraEnabled
    public Integer pendingReview { get; set; }
    
    @AuraEnabled
    public Integer reviewed { get; set; }
    
    @AuraEnabled
    public Integer skipped { get; set; }
    
    /**
     * @description Default constructor
     */
    public BulkMatchingStatus() {
        this.status = 'NOT_STARTED';
        this.totalItems = 0;
        this.processedItems = 0;
        this.matchedItems = 0;
        this.needsReviewItems = 0;
        this.progressPercentage = 0.0;
        this.cacheHits = 0;
        this.deduplicated = 0;
        this.llmCalls = 0;
        this.costSaved = 0.0;
        this.pendingReview = 0;
        this.reviewed = 0;
        this.skipped = 0;
    }
    
    /**
     * @description Calculate progress percentage
     */
    public void calculateProgress() {
        if (this.totalItems > 0) {
            this.progressPercentage = (Decimal.valueOf(this.processedItems) / Decimal.valueOf(this.totalItems)) * 100.0;
        } else {
            this.progressPercentage = 0.0;
        }
    }
}
