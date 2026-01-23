import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import startBulkMatching from '@salesforce/apex/USEEIOMatchingService.startBulkMatching';
import getMatchingStatus from '@salesforce/apex/USEEIOMatchingService.getMatchingStatus';
import getItemsNeedingReview from '@salesforce/apex/USEEIOMatchingService.getItemsNeedingReview';
import markItemAsReviewed from '@salesforce/apex/USEEIOMatchingService.markItemAsReviewed';
import markItemsAsReviewed from '@salesforce/apex/USEEIOMatchingService.markItemsAsReviewed';

// Field references for Scope3PcmtSummary
import BULK_MATCHING_STATUS_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Status__c';
import PCMT_EMSSN_FCTR_ID_FIELD from '@salesforce/schema/Scope3PcmtSummary.PcmtEmssnFctrId';
import BULK_MATCHING_ITEMS_PROCESSED_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Items_Processed__c';
import BULK_MATCHING_ITEMS_MATCHED_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Items_Matched__c';
import BULK_MATCHING_ITEMS_NEEDING_REVIEW_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Items_Needing_Review__c';
import BULK_MATCHING_CACHE_HITS_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Cache_Hits__c';
import BULK_MATCHING_DEDUPLICATED_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Deduplicated__c';
import BULK_MATCHING_LLM_CALLS_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_LLM_Calls__c';
import BULK_MATCHING_COST_SAVED_FIELD from '@salesforce/schema/Scope3PcmtSummary.Bulk_Matching_Cost_Saved__c';

const FIELDS = [
    BULK_MATCHING_STATUS_FIELD,
    PCMT_EMSSN_FCTR_ID_FIELD,
    BULK_MATCHING_ITEMS_PROCESSED_FIELD,
    BULK_MATCHING_ITEMS_MATCHED_FIELD,
    BULK_MATCHING_ITEMS_NEEDING_REVIEW_FIELD,
    BULK_MATCHING_CACHE_HITS_FIELD,
    BULK_MATCHING_DEDUPLICATED_FIELD,
    BULK_MATCHING_LLM_CALLS_FIELD,
    BULK_MATCHING_COST_SAVED_FIELD
];

export default class BulkMatchingSummary extends LightningElement {
    @api recordId; // Scope3PcmtSummary record ID
    
    // Status data
    matchingStatus = null;
    itemsNeedingReview = [];
    
    // UI state
    isLoading = false;
    isPolling = false;
    pollingInterval = null;
    
    // Wire result for refresh
    wiredStatusResult;
    wiredItemsResult;
    
    // Wire record data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredSummary({ error, data }) {
        if (data) {
            this.loadStatus();
        } else if (error) {
            this.showToast('Error', 'Failed to load summary data', 'error');
        }
    }
    
    // Wire status
    @wire(getMatchingStatus, { scope3PcmtSummaryId: '$recordId' })
    wiredStatus(result) {
        this.wiredStatusResult = result;
        if (result.data) {
            this.matchingStatus = result.data;
            this.checkPolling();
        } else if (result.error) {
            console.error('Error loading status:', result.error);
        }
    }
    
    // Wire items needing review
    @wire(getItemsNeedingReview, { scope3PcmtSummaryId: '$recordId' })
    wiredItems(result) {
        this.wiredItemsResult = result;
        if (result.data) {
            this.itemsNeedingReview = result.data;
        } else if (result.error) {
            console.error('Error loading items:', result.error);
        }
    }
    
    // Getters
    get currentStatus() {
        return this.matchingStatus ? this.matchingStatus.status : 'NOT_STARTED';
    }
    
    get statusLabel() {
        const statusMap = {
            'NOT_STARTED': 'Not Started',
            'IN_PROGRESS': 'In Progress',
            'COMPLETE': 'Complete',
            'ERROR': 'Error'
        };
        return statusMap[this.currentStatus] || 'Unknown';
    }
    
    get statusClass() {
        const classMap = {
            'NOT_STARTED': 'slds-badge slds-badge_neutral',
            'IN_PROGRESS': 'slds-badge slds-theme_info',
            'COMPLETE': 'slds-badge slds-theme_success',
            'ERROR': 'slds-badge slds-theme_error'
        };
        return classMap[this.currentStatus] || 'slds-badge slds-badge_neutral';
    }
    
    get canStartMatching() {
        return !this.isLoading && 
               this.currentStatus !== 'IN_PROGRESS' && 
               this.hasFactorSet;
    }
    
    get hasFactorSet() {
        return getFieldValue(this.wiredSummary?.data, PCMT_EMSSN_FCTR_ID_FIELD) != null;
    }
    
    get progressPercentage() {
        return this.matchingStatus ? this.matchingStatus.progressPercentage : 0;
    }
    
    get hasItemsNeedingReview() {
        return this.itemsNeedingReview && this.itemsNeedingReview.length > 0;
    }
    
    get reviewProgressPercentage() {
        if (this.matchingStatus && this.matchingStatus.needsReviewItems > 0) {
            const reviewed = this.matchingStatus.reviewed || 0;
            const total = this.matchingStatus.needsReviewItems;
            return Math.round((reviewed / total) * 100);
        }
        return 0;
    }
    
    get hasSelectedRows() {
        return this.selectedRows && this.selectedRows.length > 0;
    }
    
    get reviewProgressText() {
        if (this.matchingStatus) {
            const pending = this.matchingStatus.pendingReview || 0;
            const reviewed = this.matchingStatus.reviewed || 0;
            const skipped = this.matchingStatus.skipped || 0;
            return `${reviewed} reviewed, ${skipped} skipped, ${pending} pending`;
        }
        return '0 reviewed, 0 skipped, 0 pending';
    }
    
    get costSavedFormatted() {
        if (this.matchingStatus && this.matchingStatus.costSaved) {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                minimumFractionDigits: 2
            }).format(this.matchingStatus.costSaved);
        }
        return '$0.00';
    }
    
    // Methods
    async handleStartMatching() {
        this.isLoading = true;
        
        try {
            const response = await startBulkMatching({ scope3PcmtSummaryId: this.recordId });
            
            if (response.success) {
                this.showToast('Success', 'Bulk matching started successfully', 'success');
                // Refresh status
                await refreshApex(this.wiredStatusResult);
                await refreshApex(this.wiredSummary);
                // Start polling
                this.startPolling();
            } else {
                this.showToast('Error', response.error || 'Failed to start bulk matching', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'Failed to start bulk matching', 'error');
            console.error('Error starting bulk matching:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    loadStatus() {
        // Status is loaded via wire service
        // This method can be used for manual refresh if needed
        refreshApex(this.wiredStatusResult);
        refreshApex(this.wiredItemsResult);
    }
    
    startPolling() {
        // Only poll if status is IN_PROGRESS
        if (this.currentStatus === 'IN_PROGRESS' && !this.isPolling) {
            this.isPolling = true;
            this.pollingInterval = setInterval(() => {
                this.loadStatus();
            }, 5000); // Poll every 5 seconds
        }
    }
    
    stopPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
            this.isPolling = false;
        }
    }
    
    checkPolling() {
        // Stop polling if status is not IN_PROGRESS
        if (this.currentStatus !== 'IN_PROGRESS') {
            this.stopPolling();
        } else {
            this.startPolling();
        }
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    // Cleanup on component destroy
    disconnectedCallback() {
        this.stopPolling();
    }
}
