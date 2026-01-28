import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import BulkMatchingSummaryModal from 'c/bulkMatchingSummaryModal';

import startBulkMatching from '@salesforce/apex/USEEIOMatchingService.startBulkMatching';
import getMatchingStatus from '@salesforce/apex/USEEIOMatchingService.getMatchingStatus';
import getItemsNeedingReview from '@salesforce/apex/USEEIOMatchingService.getItemsNeedingReview';
import markItemAsReviewed from '@salesforce/apex/USEEIOMatchingService.markItemAsReviewed';
import markItemsAsReviewed from '@salesforce/apex/USEEIOMatchingService.markItemsAsReviewed';
import searchFactorSetItems from '@salesforce/apex/USEEIOMatchingService.searchFactorSetItems';
import updateItemFactorSetItem from '@salesforce/apex/USEEIOMatchingService.updateItemFactorSetItem';

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
    draftValues = []; // Store draft values for inline editing
    currentEditingItem = null; // Item currently being edited for lookup
    showLookupModal = false; // Control lookup modal visibility
    
    // UI state
    isLoading = false;
    isPolling = false;
    pollingInterval = null;
    isFullScreen = false; // Full-screen mode toggle
    localStatus = null; // Optimistic status for immediate UI update
    previousStatus = null; // Track status changes for notifications
    
    // Wire result for refresh
    wiredStatusResult;
    wiredItemsResult;
    wiredSummaryResult;
    
    // Data table columns for items needing review
    get reviewTableColumns() {
        const baseColumns = [
            { label: 'Name', fieldName: 'Name', type: 'text', wrapText: true },
            { label: 'Category 1', fieldName: 'SpendingCategory1', type: 'text', wrapText: true },
            { label: 'Category 2', fieldName: 'SpendingCategory2', type: 'text', wrapText: true },
            { label: 'Category 3', fieldName: 'SpendingCategory3', type: 'text', wrapText: true },
            { label: 'Confidence', fieldName: 'Match_Confidence_Score__c', type: 'percent', typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 } },
            { label: 'Reasoning', fieldName: 'Match_Reasoning__c', type: 'text', wrapText: true }
        ];
        
        // Add lookup column if we have a factor set ID
        // Use text column to display current value, action column for button
        if (this.factorSetId) {
            baseColumns.push({
                label: 'Emissions Factor',
                fieldName: 'factorSetItemDisplayName',
                type: 'text',
                wrapText: true,
                cellAttributes: { alignment: 'left' }
            });
            // Add action column for lookup button
            baseColumns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Select Factor', name: 'select_factor', iconName: 'utility:search' }
                    ],
                    menuAlignment: 'left'
                },
                fixedWidth: 50
            });
        }
        
        return baseColumns;
    }
    
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
            const newStatus = result.data.status;
            const oldStatus = this.previousStatus || (this.matchingStatus ? this.matchingStatus.status : null);
            
            // Detect status transition for notifications
            if (oldStatus === 'IN_PROGRESS' && newStatus === 'COMPLETE') {
                // Job just completed - show notification
                this.showToast(
                    'Bulk Matching Complete',
                    `Successfully processed ${result.data.processedItems} items. ${result.data.matchedItems} matched, ${result.data.needsReviewItems} need review.`,
                    'success'
                );
            }
            
            // Update previous status before updating matchingStatus
            this.previousStatus = this.matchingStatus ? this.matchingStatus.status : null;
            
            // Update status
            this.matchingStatus = result.data;
            
            // Clear local status once we have real status (if it matches)
            if (this.localStatus && this.matchingStatus && this.localStatus === this.matchingStatus.status) {
                this.localStatus = null;
            }
            
            this.checkPolling();
        } else if (result.error) {
            console.error('Error loading status:', result.error);
            // Clear local status on error
            this.localStatus = null;
        }
    }
    
    // Wire items needing review
    @wire(getItemsNeedingReview, { scope3PcmtSummaryId: '$recordId' })
    wiredItems(result) {
        this.wiredItemsResult = result;
        if (result.data) {
            // Transform to include lookup display name
            // Ensure all items have a valid Id field for the datatable
            // IMPORTANT: Create new objects (don't mutate original) and ensure Id is a string
            this.itemsNeedingReview = result.data.map(item => {
                // Create a completely new object to avoid any reference issues
                const transformedItem = {
                    Id: String(item.Id), // Ensure Id is always a string
                    Name: item.Name || '',
                    SpendingCategory1: item.SpendingCategory1 || '',
                    SpendingCategory2: item.SpendingCategory2 || '',
                    SpendingCategory3: item.SpendingCategory3 || '',
                    Match_Confidence_Score__c: item.Match_Confidence_Score__c,
                    Match_Reasoning__c: item.Match_Reasoning__c || '',
                    PcmtEmssnFctrSetItemId: item.PcmtEmssnFctrSetItemId || null,
                    factorSetItemDisplayName: item.PcmtEmssnFctrSetItem?.Name || 'Click to select'
                };
                // Ensure Id is always present
                if (!transformedItem.Id) {
                    console.error('Item missing Id:', item);
                }
                return transformedItem;
            });
        } else if (result.error) {
            console.error('Error loading items:', result.error);
            this.itemsNeedingReview = [];
        }
    }
    
    // Handle row selection in data table
    handleRowSelection(event) {
        try {
            if (!event || !event.detail) {
                console.warn('Invalid row selection event:', event);
                return;
            }
            
            const selectedRows = event.detail.selectedRows || [];
            console.log('Row selection event - selectedRows:', selectedRows);
            
            // lightning-datatable passes selectedRows as an array of row objects
            // The row objects should have an Id property that matches our key-field
            this.selectedRows = selectedRows.map(row => {
                // Handle both object and string formats
                if (typeof row === 'string') {
                    return String(row);
                }
                // Extract Id from row object - ensure it's a string
                // lightning-datatable should pass the full row object with Id
                const id = String(row.Id || row.id || '');
                if (!id || id === 'undefined' || id === 'null' || id === '') {
                    console.warn('Row missing valid Id:', row);
                    return null;
                }
                return id;
            }).filter(id => id != null && id !== 'undefined' && id !== 'null' && id !== ''); // Remove any null/undefined/invalid IDs
            
            console.log('Row selection updated:', this.selectedRows);
        } catch (error) {
            console.error('Error handling row selection:', error);
            console.error('Error stack:', error.stack);
            console.error('Event details:', event);
            // Don't clear selectedRows on error, just log it
        }
    }
    
    // Handle row action (for lookup button)
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        if (action.name === 'select_factor') {
            this.openLookupModal(row);
        }
    }
    
    // Open lookup modal for a specific item
    openLookupModal(item) {
        console.log('Opening lookup modal for item:', item);
        console.log('factorSetId:', this.factorSetId);
        // Store the current item being edited - create a clean copy
        this.currentEditingItem = {
            Id: item.Id,
            PcmtEmssnFctrSetItemId: item.PcmtEmssnFctrSetItemId,
            factorSetItemDisplayName: item.factorSetItemDisplayName
        };
        // Show lookup modal
        this.showLookupModal = true;
    }
    
    // Close lookup modal
    closeLookupModal() {
        this.showLookupModal = false;
        this.currentEditingItem = null;
    }
    
    // Getters
    get currentStatus() {
        // Use local status if set (for immediate UI update), otherwise use actual status
        if (this.localStatus) {
            return this.localStatus;
        }
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
               this.hasFactorSet &&
               this.hasUnmatchedItems;
        // Use debug getter for logging
        this.canStartMatchingDebug;
        return result;
    }
    
    get hasUnmatchedItems() {
        // Check if there are any unmatched items
        // If status is complete and all items are matched, disable button
        if (this.matchingStatus && this.matchingStatus.complete) {
            // If total items = matched items, no unmatched items remain
            const hasUnmatched = this.matchingStatus.totalItems > this.matchingStatus.matchedItems;
            return hasUnmatched;
        }
        // If status is not complete or no status yet, assume there might be items to match
        // (We can't know for sure until we check, so allow button to be enabled)
        return true;
    }
    
    get cardClass() {
        // Add full-screen class when in full-screen mode
        return this.isFullScreen ? 'slds-card slds-card_full-width' : '';
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
               this.hasFactorSet &&
               this.hasUnmatchedItems;
        console.log('canStartMatching check:', {
            isLoading: this.isLoading,
            currentStatus: this.currentStatus,
            hasFactorSet: this.hasFactorSet,
            hasUnmatchedItems: this.hasUnmatchedItems,
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
    
    // Helper to check if an item is selected (for checkbox checked state)
    isItemSelected(itemId) {
        if (!this.selectedRows || !itemId) {
            return false;
        }
        return this.selectedRows.includes(itemId);
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
    
    get isInProgress() {
        return this.currentStatus === 'IN_PROGRESS';
    }
    
    // Methods
    async handleStartMatching() {
        this.isLoading = true;
        
        // Optimistic UI update - set status to IN_PROGRESS immediately
        this.localStatus = 'IN_PROGRESS';
        
        try {
            const response = await startBulkMatching({ scope3PcmtSummaryId: this.recordId });
            
            if (response.success) {
                this.showToast('Success', 'Bulk matching started successfully', 'success');
                // Refresh status to get real data
                await refreshApex(this.wiredStatusResult);
                await refreshApex(this.wiredSummaryResult);
                // Start polling - localStatus will be cleared when real status loads
                this.startPolling();
            } else {
                // Clear local status on error
                this.localStatus = null;
                this.showToast('Error', response.error || 'Failed to start bulk matching', 'error');
            }
        } catch (error) {
            // Clear local status on error
            this.localStatus = null;
            this.showToast('Error', error.body?.message || error.message || 'Failed to start bulk matching', 'error');
            console.error('Error starting bulk matching:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    // Handle refresh button click
    async handleRefresh() {
        this.isLoading = true;
        try {
            // Refresh all wired data
            await refreshApex(this.wiredStatusResult);
            await refreshApex(this.wiredItemsResult);
            await refreshApex(this.wiredSummaryResult);
            this.showToast('Success', 'Data refreshed', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to refresh data', 'error');
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    // Handle full-screen modal
    handleToggleFullScreen() {
        BulkMatchingSummaryModal.open({
            label: 'Bulk Emissions Factor Matching',
            size: 'large',
            description: 'Full screen view of bulk matching interface',
            recordId: this.recordId
        }).catch(error => {
            console.error('Error opening modal:', error);
        });
    }
    
    get fullScreenIcon() {
        return 'utility:expand_all';
    }
    
    get fullScreenLabel() {
        return 'Open in Full Screen';
    }
    
    get cardClass() {
        return '';
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
    
    // Handle row selection checkbox change
    handleRowCheckboxChange(event) {
        const itemId = event.target.dataset.itemId;
        const isChecked = event.target.checked;
        
        if (isChecked) {
            if (!this.selectedRows.includes(itemId)) {
                this.selectedRows = [...this.selectedRows, itemId];
            }
        } else {
            this.selectedRows = this.selectedRows.filter(id => id !== itemId);
        }
        
        // Update the isSelected property on the item
        const item = this.itemsNeedingReview.find(i => i.Id === itemId);
        if (item) {
            item.isSelected = isChecked;
        }
    }
    
    // Handle select all checkbox
    handleSelectAll(event) {
        const isChecked = event.target.checked;
        
        if (isChecked) {
            this.selectedRows = this.itemsNeedingReview.map(item => item.Id);
            // Update all items' isSelected property
            this.itemsNeedingReview.forEach(item => {
                item.isSelected = true;
            });
        } else {
            this.selectedRows = [];
            // Update all items' isSelected property
            this.itemsNeedingReview.forEach(item => {
                item.isSelected = false;
            });
        }
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
    
    // Handle lookup change from custom component
    async handleLookupChange(event) {
        const { itemId, factorSetItemId, factorSetItemName } = event.detail;
        
        if (!itemId) {
            return;
        }
        
        this.isLoading = true;
        
        try {
            const response = await updateItemFactorSetItem({
                itemId: itemId,
                factorSetItemId: factorSetItemId
            });
            
            if (response.success) {
                this.showToast('Success', 'Emissions factor updated successfully', 'success');
                // Close the modal
                this.closeLookupModal();
                // Refresh the data
                await refreshApex(this.wiredItemsResult);
            } else {
                throw new Error(response.error || 'Failed to update item');
            }
        } catch (error) {
            console.error('Error updating item:', error);
            this.showToast('Error', error.body?.message || error.message || 'Failed to update item', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    // Cleanup on component destroy
    disconnectedCallback() {
        this.stopPolling();
    }
}
