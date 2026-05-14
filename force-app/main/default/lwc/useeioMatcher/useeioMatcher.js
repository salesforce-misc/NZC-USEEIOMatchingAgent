/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import matchSpendItemToFactor from '@salesforce/apex/USEEIOMatchingService.matchSpendItemToFactor';
import applyMatchFromResult from '@salesforce/apex/USEEIOMatchingService.applyMatchFromResult';

// Field references for Scope3PcmtItem
const SPENDING_CATEGORY_1_FIELD = 'Scope3PcmtItem.SpendingCategory1';
const SPENDING_CATEGORY_2_FIELD = 'Scope3PcmtItem.SpendingCategory2';
const SPENDING_CATEGORY_3_FIELD = 'Scope3PcmtItem.SpendingCategory3';
const FACTOR_ID_FIELD = 'Scope3PcmtItem.PcmtEmssnFctrSetItemId';
const CONFIDENCE_SCORE_FIELD = 'Scope3PcmtItem.Match_Confidence_Score__c';
const REASONING_FIELD = 'Scope3PcmtItem.Match_Reasoning__c';
const MATCH_SOURCE_FIELD = 'Scope3PcmtItem.Match_Source__c';

const FIELDS = [
    SPENDING_CATEGORY_1_FIELD,
    SPENDING_CATEGORY_2_FIELD,
    SPENDING_CATEGORY_3_FIELD,
    FACTOR_ID_FIELD,
    CONFIDENCE_SCORE_FIELD,
    REASONING_FIELD,
    MATCH_SOURCE_FIELD
];

/**
 * Lightning Web Component for matching Scope3PcmtItem to emissions factors
 * Embedded on Scope3PcmtItem record page
 */
export default class UseeioMatcher extends LightningElement {
    @api recordId; // Automatically populated from page context
    
    // Record data
    spendingCategory1;
    spendingCategory2;
    spendingCategory3;
    currentFactorId;
    currentConfidenceScore;
    currentReasoning;
    currentMatchSource;
    
    // Matching state
    isLoading = false;
    matchingResult = null;
    hasMatch = false;
    showResults = false;
    
    // Wire record data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.spendingCategory1 = getFieldValue(data, SPENDING_CATEGORY_1_FIELD);
            this.spendingCategory2 = getFieldValue(data, SPENDING_CATEGORY_2_FIELD);
            this.spendingCategory3 = getFieldValue(data, SPENDING_CATEGORY_3_FIELD);
            this.currentFactorId = getFieldValue(data, FACTOR_ID_FIELD);
            this.currentConfidenceScore = getFieldValue(data, CONFIDENCE_SCORE_FIELD);
            this.currentReasoning = getFieldValue(data, REASONING_FIELD);
            this.currentMatchSource = getFieldValue(data, MATCH_SOURCE_FIELD);
            this.hasMatch = this.currentFactorId != null;
        } else if (error) {
            this.showError('Error loading record', error.body?.message || 'Unknown error');
        }
    }
    
    /**
     * Handle Find Emissions Factor button click
     */
    handleFindMatch() {
        if (!this.recordId) {
            this.showError('Error', 'No record ID available');
            return;
        }
        
        this.isLoading = true;
        this.showResults = false;
        this.matchingResult = null;
        
        matchSpendItemToFactor({ scope3PcmtItemId: this.recordId })
            .then(result => {
                this.matchingResult = result;
                this.showResults = true;
                this.isLoading = false;
                
                if (result.status === 'NO_MATCH') {
                    this.showWarning('No Match Found', result.errorMessage || 'Unable to find a matching emissions factor');
                } else if (result.status === 'REQUIRES_REVIEW') {
                    this.showWarning('Review Required', 'Match found but confidence is low. Please review before applying.');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.showError('Matching Error', error.body?.message || 'An error occurred while finding a match');
                console.error('Matching error:', error);
            });
    }
    
    /**
     * Handle Apply Match button click
     */
    handleApplyMatch() {
        if (!this.matchingResult || !this.matchingResult.recommendedFactorId) {
            this.showError('Error', 'No match to apply');
            return;
        }
        
        this.isLoading = true;
        
        applyMatchFromResult({ result: this.matchingResult })
            .then(response => {
                this.isLoading = false;
                if (response.success) {
                    this.showSuccess('Match Applied', 'Emissions factor has been successfully linked to this procurement item');
                    this.hasMatch = true;
                    this.currentFactorId = this.matchingResult.recommendedFactorId;
                    this.currentConfidenceScore = this.matchingResult.confidenceScore;
                    this.currentReasoning = this.matchingResult.reasoning;
                    this.currentMatchSource = 'AI Suggested';
                    
                    // Refresh the record to show updated fields
                    this.refreshRecord();
                } else {
                    const errorMsg = response.error || 'Failed to apply match';
                    this.showError('Apply Failed', errorMsg);
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.showError('Apply Error', error.body?.message || 'An error occurred while applying the match');
                console.error('Apply error:', error);
            });
    }
    
    /**
     * Handle Try Again button click
     */
    handleTryAgain() {
        this.showResults = false;
        this.matchingResult = null;
    }
    
    /**
     * Get confidence level label (High, Medium, Low)
     */
    get confidenceLevel() {
        if (!this.matchingResult || !this.matchingResult.confidenceScore) {
            return 'Unknown';
        }
        const score = this.matchingResult.confidenceScore;
        if (score >= 0.76) return 'High';
        if (score >= 0.51) return 'Medium';
        return 'Low';
    }
    
    /**
     * Get confidence level CSS class for styling
     */
    get confidenceClass() {
        if (!this.matchingResult || !this.matchingResult.confidenceScore) {
            return 'slds-badge slds-badge_neutral';
        }
        const score = this.matchingResult.confidenceScore;
        if (score >= 0.76) return 'slds-badge slds-badge_success';
        if (score >= 0.51) return 'slds-badge slds-badge_warning';
        return 'slds-badge slds-badge_error';
    }
    
    /**
     * Get confidence percentage for display
     */
    get confidencePercentage() {
        if (!this.matchingResult || !this.matchingResult.confidenceScore) {
            return 0;
        }
        return Math.round(this.matchingResult.confidenceScore * 100);
    }
    
    /**
     * Check if spending categories are available
     */
    get hasSpendingCategories() {
        return this.spendingCategory1 || this.spendingCategory2 || this.spendingCategory3;
    }
    
    get buttonDisabled() {
        return this.isLoading || !this.hasSpendingCategories;
    }
    
    get applyButtonDisabled() {
        return this.isLoading || !this.canApplyMatch;
    }
    
    /**
     * Get current confidence class for existing match
     */
    get currentConfidenceClass() {
        if (!this.currentConfidenceScore) {
            return 'slds-badge slds-badge_neutral';
        }
        const score = this.currentConfidenceScore;
        if (score >= 0.76) return 'slds-badge slds-badge_success';
        if (score >= 0.51) return 'slds-badge slds-badge_warning';
        return 'slds-badge slds-badge_error';
    }
    
    /**
     * Get current confidence percentage for display
     */
    get currentConfidencePercentage() {
        if (!this.currentConfidenceScore) {
            return 0;
        }
        return Math.round(this.currentConfidenceScore * 100);
    }
    
    /**
     * Check if match can be applied
     */
    get canApplyMatch() {
        return this.matchingResult && 
               this.matchingResult.recommendedFactorId && 
               this.matchingResult.status !== 'NO_MATCH' &&
               !this.isLoading;
    }
    
    /**
     * Refresh the record data
     */
    refreshRecord() {
        // Force refresh of wired record
        this.recordId = this.recordId;
    }
    
    /**
     * Show success toast
     */
    showSuccess(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'success',
                mode: 'dismissable'
            })
        );
    }
    
    /**
     * Show error toast
     */
    showError(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }
    
    /**
     * Show warning toast
     */
    showWarning(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'warning',
                mode: 'dismissable'
            })
        );
    }
}
