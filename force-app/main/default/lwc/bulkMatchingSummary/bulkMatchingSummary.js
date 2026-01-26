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
    selectedRows = [];
    factorSetId = null; // Store factor set ID directly
    
    // UI state
    isLoading = false;
    isPolling = false;
    pollingInterval = null;
    
    // Wire result for refresh
    wiredStatusResult;
    wiredItemsResult;
    
    // Data table columns for items needing review
    reviewTableColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Category 1', fieldName: 'SpendingCategory1', type: 'text' },
        { label: 'Category 2', fieldName: 'SpendingCategory2', type: 'text' },
        { label: 'Category 3', fieldName: 'SpendingCategory3', type: 'text' },
        { label: 'Confidence', fieldName: 'Match_Confidence_Score__c', type: 'percent', typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 } },
        { label: 'Reasoning', fieldName: 'Match_Reasoning__c', type: 'text', wrapText: true }
    ];
    
    // Wire record data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredSummary(result) {
        this.wiredSummaryResult = result; // Store the result object so hasFactorSet can access it
        const { data, error } = result;
        console.log('wiredSummary called - storing result:', result);
        if (data) {
            // Store factor set ID directly for faster access
            this.factorSetId = getFieldValue(data, PCMT_EMSSN_FCTR_ID_FIELD);
            console.log('Wire service loaded data:', data);
            console.log('PcmtEmssnFctrId value:', this.factorSetId);
            console.log('All field values:', {
                status: getFieldValue(data, BULK_MATCHING_STATUS_FIELD),
                factorSetId: this.factorSetId,
                processed: getFieldValue(data, BULK_MATCHING_ITEMS_PROCESSED_FIELD)
            });
            this.loadStatus();
        } else if (error) {
            console.error('Wire service error:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            const errorMsg = error.body?.message || error.message || error.toString() || 'Unknown error';
            console.error('Error message:', errorMsg);
            this.showToast('Error', 'Failed to load summary data: ' + errorMsg, 'error');
        } else {
            console.log('Wire service: No data and no error (still loading?)');
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
        const result = !this.isLoading && 
               this.currentStatus !== 'IN_PROGRESS' && 
               this.hasFactorSet;
        // Use debug getter for logging
        this.canStartMatchingDebug;
        return result;
    }
    
    get isStartButtonDisabled() {
        return !this.canStartMatching;
    }
    
    get hasFactorSet() {
        // Use directly stored factorSetId for faster access
        const hasFactorSet = this.factorSetId != null;
        console.log('hasFactorSet getter - factorSetId:', this.factorSetId, 'hasFactorSet:', hasFactorSet);
        return hasFactorSet;
    }
    
    get canStartMatchingDebug() {
        const result = !this.isLoading && 
               this.currentStatus !== 'IN_PROGRESS' && 
               this.hasFactorSet;
        console.log('canStartMatching check:', {
            isLoading: this.isLoading,
            currentStatus: this.currentStatus,
            hasFactorSet: this.hasFactorSet,
            result: result
        });
        return result;
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
    
    get isActionButtonsDisabled() {
        return !this.hasSelectedRows;
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
    
    get cacheHitsDisplay() {
        return this.matchingStatus && this.matchingStatus.cacheHits ? this.matchingStatus.cacheHits : 0;
    }
    
    get deduplicatedDisplay() {
        return this.matchingStatus && this.matchingStatus.deduplicated ? this.matchingStatus.deduplicated : 0;
    }
    
    get llmCallsDisplay() {
        return this.matchingStatus && this.matchingStatus.llmCalls ? this.matchingStatus.llmCalls : 0;
    }
    
    get progressBarStyle() {
        return `width: ${this.progressPercentage}%`;
    }
    
    get reviewProgressBarStyle() {
        return `width: ${this.reviewProgressPercentage}%`;
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
                await refreshApex(this.wiredSummaryResult);
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
    
    // Handle row selection in data table
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(row => row.Id);
    }
    
    // Handle marking items as reviewed
    async handleMarkAsReviewed() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select items to mark as reviewed', 'warning');
            return;
        }
        
        this.isLoading = true;
        try {
            const response = await markItemsAsReviewed({ 
                itemIds: this.selectedRows,
                reviewStatus: 'Reviewed'
            });
            
            if (response.success) {
                this.showToast('Success', `${this.selectedRows.length} item(s) marked as reviewed`, 'success');
                this.selectedRows = [];
                // Refresh data
                await refreshApex(this.wiredStatusResult);
                await refreshApex(this.wiredItemsResult);
            } else {
                this.showToast('Error', response.error || 'Failed to mark items as reviewed', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'Failed to mark items as reviewed', 'error');
            console.error('Error marking items as reviewed:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    // Handle marking items as skipped
    async handleMarkAsSkipped() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select items to skip', 'warning');
            return;
        }
        
        this.isLoading = true;
        try {
            const response = await markItemsAsReviewed({ 
                itemIds: this.selectedRows,
                reviewStatus: 'Skipped'
            });
            
            if (response.success) {
                this.showToast('Success', `${this.selectedRows.length} item(s) marked as skipped`, 'success');
                this.selectedRows = [];
                // Refresh data
                await refreshApex(this.wiredStatusResult);
                await refreshApex(this.wiredItemsResult);
            } else {
                this.showToast('Error', response.error || 'Failed to mark items as skipped', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'Failed to mark items as skipped', 'error');
            console.error('Error marking items as skipped:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    // Cleanup on component destroy
    disconnectedCallback() {
        this.stopPolling();
    }
}
