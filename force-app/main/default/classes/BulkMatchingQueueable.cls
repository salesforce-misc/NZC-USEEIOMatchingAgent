/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Queueable class to initiate bulk matching batch job
 * @description Entry point for bulk matching from LWC (can be called from @AuraEnabled method)
 * @author Your Name
 * @date 2025-01-XX
 */
public class BulkMatchingQueueable implements Queueable {
    private Id scope3PcmtSummaryId;
    
    /**
     * @description Constructor
     * @param summaryId Scope3PcmtSummary record ID
     */
    public BulkMatchingQueueable(Id summaryId) {
        this.scope3PcmtSummaryId = summaryId;
    }
    
    /**
     * @description Execute method - validates and enqueues batch job
     * @param context Queueable context
     */
    public void execute(QueueableContext context) {
        try {
            // Validate summary exists and has factor set
            Scope3PcmtSummary summary = [
                SELECT Id, PcmtEmssnFctrId
                FROM Scope3PcmtSummary
                WHERE Id = :scope3PcmtSummaryId
                LIMIT 1
            ];
            
            if (summary.PcmtEmssnFctrId == null) {
                // Update summary with error status
                summary.Bulk_Matching_Status__c = 'Error';
                update summary;
                throw new BulkMatchingException('Procurement Summary must have a Procurement Emissions Factor Set');
            }
            
            // Check if there are items to process
            Integer itemCount = [
                SELECT COUNT()
                FROM Scope3PcmtItem
                WHERE ProcurementSummaryId = :scope3PcmtSummaryId
                AND PcmtEmssnFctrSetItemId = null
            ];
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingQueueable.execute - UNMATCHED ITEMS COUNT: itemCount=' + itemCount + ', summaryId=' + scope3PcmtSummaryId);
            // #endregion
            
            if (itemCount == 0) {
                // No items to process
                summary.Bulk_Matching_Status__c = 'Complete';
                summary.Bulk_Matching_Items_Processed__c = 0;
                summary.Bulk_Matching_Items_Matched__c = 0;
                summary.Bulk_Matching_Items_Needing_Review__c = 0;
                update summary;
                return;
            }
            
            // Update summary status to In Progress
            summary.Bulk_Matching_Status__c = 'In Progress';
            summary.Bulk_Matching_Items_Processed__c = 0;
            summary.Bulk_Matching_Items_Matched__c = 0;
            summary.Bulk_Matching_Items_Needing_Review__c = 0;
            summary.Bulk_Matching_Cache_Hits__c = 0;
            summary.Bulk_Matching_Deduplicated__c = 0;
            summary.Bulk_Matching_LLM_Calls__c = 0;
            summary.Bulk_Matching_Cost_Saved__c = 0;
            
            // #region agent log
            System.debug('[DEBUG] BulkMatchingQueueable.execute - BEFORE UPDATE: setting status=In Progress, processed=0, unmatchedItems=' + itemCount);
            // #endregion
            
            update summary;
            
            // Enqueue Batch Apex job
            // Batch size of 25 matches our processing limit (MAX_ITEMS_PER_EXECUTION)
            // This ensures all items passed to execute() are actually processed
            // For tens of thousands of items, Batch Apex will automatically create multiple executions
            // Each execution processes 25 items, allowing the job to scale to any volume
            BulkMatchingBatch batch = new BulkMatchingBatch(scope3PcmtSummaryId);
            Id jobId = Database.executeBatch(batch, 25);
            
            // Store job ID on summary
            summary.Bulk_Matching_Job_Id__c = String.valueOf(jobId);
            update summary;
            
        } catch (Exception e) {
            // Update summary with error status
            try {
                Scope3PcmtSummary summary = [
                    SELECT Id
                    FROM Scope3PcmtSummary
                    WHERE Id = :scope3PcmtSummaryId
                    LIMIT 1
                ];
                summary.Bulk_Matching_Status__c = 'Error';
                update summary;
            } catch (Exception updateEx) {
                System.debug('Failed to update summary status: ' + updateEx.getMessage());
            }
            
            throw new BulkMatchingException('Failed to start bulk matching: ' + e.getMessage(), e);
        }
    }
    
    /**
     * @description Custom exception class
     */
    public class BulkMatchingException extends Exception {}
}
