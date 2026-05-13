import { LightningElement, api, wire } from 'lwc';
import searchFactorSetItems from '@salesforce/apex/USEEIOMatchingService.searchFactorSetItems';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

const FACTOR_ITEM_FIELDS = ['PcmtEmssnFctrSetItem.Id', 'PcmtEmssnFctrSetItem.Name'];

export default class FactorSetItemLookup extends LightningElement {
    @api value; // The current PcmtEmssnFctrSetItemId
    @api factorSetId; // The parent PcmtEmssnFctrSet ID for filtering
    @api itemId; // The Scope3PcmtItem ID
    @api displayName; // The display name of the current factor set item
    
    searchTerm = '';
    options = [];
    selectedValue = null;
    selectedName = '';
    showDropdown = false;
    isLoading = false;
    
    connectedCallback() {
        console.log('FactorSetItemLookup connectedCallback - factorSetId:', this.factorSetId, 'value:', this.value, 'displayName:', this.displayName);
        
        if (this.value) {
            this.selectedValue = this.value;
            // Use display name if provided
            if (this.displayName) {
                this.selectedName = this.displayName;
                this.searchTerm = this.displayName;
            }
        }
        
        // Log if factorSetId is missing
        if (!this.factorSetId) {
            console.error('FactorSetItemLookup - factorSetId is missing! This will prevent searching.');
        }
    }
    
    // Watch for value and displayName changes
    renderedCallback() {
        if (this.value && this.value !== this.selectedValue) {
            this.selectedValue = this.value;
            if (this.displayName) {
                this.selectedName = this.displayName;
                this.searchTerm = this.displayName;
            }
        }
        
        // Log factorSetId to debug search issues
        if (this.factorSetId) {
            console.log('FactorSetItemLookup - factorSetId:', this.factorSetId);
        } else {
            console.warn('FactorSetItemLookup - No factorSetId provided!');
        }
    }
    
    get displayValue() {
        // Show selected name if available, otherwise show search term
        if (this.selectedValue && this.selectedName) {
            return this.selectedName;
        }
        return this.searchTerm;
    }
    
    // Stop event propagation to prevent row selection in datatable
    handleContainerClick(event) {
        event.stopPropagation();
    }
    
    handleInputClick(event) {
        event.stopPropagation();
    }
    
    handleButtonClick(event) {
        event.stopPropagation();
    }
    
    handleOptionMouseDown(event) {
        // Prevent row selection when clicking on dropdown options
        event.stopPropagation();
    }
    
    handleInputChange(event) {
        this.searchTerm = event.target.value;
        console.log('Input changed - searchTerm:', this.searchTerm, 'factorSetId:', this.factorSetId);
        
        // Clear selection if user is typing
        if (this.searchTerm !== this.selectedName) {
            this.selectedValue = null;
            this.selectedName = '';
        }
        
        if (this.searchTerm.length >= 2) {
            console.log('Search term length >= 2, calling searchItems');
            this.searchItems();
        } else {
            console.log('Search term too short, clearing options');
            this.options = [];
            this.showDropdown = false;
        }
    }
    
    async searchItems() {
        console.log('searchItems called - factorSetId:', this.factorSetId, 'searchTerm:', this.searchTerm);
        
        if (!this.factorSetId) {
            console.warn('No factorSetId provided, cannot search');
            return;
        }
        
        this.isLoading = true;
        this.showDropdown = true;
        
        try {
            console.log('Calling searchFactorSetItems with:', {
                searchTerm: this.searchTerm,
                pcmtEmssnFctrSetId: this.factorSetId
            });
            
            const results = await searchFactorSetItems({
                searchTerm: this.searchTerm,
                pcmtEmssnFctrSetId: this.factorSetId
            });
            
            console.log('Search results:', results);
            
            this.options = results.map(item => ({
                label: item.Name + (item.EconomicSectorCode ? ' (' + item.EconomicSectorCode + ')' : ''),
                value: item.Id,
                subtitle: item.EconomicSector || ''
            }));
            
            console.log('Mapped options:', this.options);
            console.log('showDropdown should be true, options count:', this.options.length);
            
            // Force dropdown to show if we have results
            if (this.options.length > 0) {
                this.showDropdown = true;
                console.log('Setting showDropdown to true, options:', this.options);
            } else {
                this.showDropdown = false;
            }
            
        } catch (error) {
            console.error('Error searching:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            this.options = [];
            this.showDropdown = false;
        } finally {
            this.isLoading = false;
            console.log('searchItems complete - showDropdown:', this.showDropdown, 'options:', this.options.length);
        }
    }
    
    handleOptionSelect(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const selectedValue = event.currentTarget.dataset.value;
        console.log('Option selected:', selectedValue);
        
        const selectedOption = this.options.find(opt => opt.value === selectedValue);
        if (selectedOption) {
            console.log('Found selected option:', selectedOption);
            this.selectedValue = selectedOption.value;
            this.selectedName = selectedOption.label;
            this.searchTerm = selectedOption.label;
            this.showDropdown = false;
            
            // Dispatch event to parent (with bubbles and composed for datatable)
            this.dispatchEvent(new CustomEvent('change', {
                detail: {
                    itemId: this.itemId,
                    factorSetItemId: selectedOption.value,
                    factorSetItemName: selectedOption.label
                },
                bubbles: true,
                composed: true
            }));
        } else {
            console.warn('Selected option not found for value:', selectedValue);
        }
    }
    
    handleFocus() {
        console.log('Input focused - searchTerm:', this.searchTerm, 'factorSetId:', this.factorSetId);
        if (this.searchTerm.length >= 2) {
            this.searchItems();
        } else if (this.searchTerm.length > 0) {
            // If there's some text but less than 2 chars, show a message
            console.log('Search term too short, need at least 2 characters');
        }
    }
    
    handleBlur(event) {
        // Delay hiding dropdown to allow option click
        setTimeout(() => {
            // Check if focus moved to dropdown
            const activeElement = document.activeElement;
            const dropdown = this.template.querySelector('#lookup-listbox');
            
            if (!dropdown || !dropdown.contains(activeElement)) {
                // Focus is not in dropdown, hide it
                this.showDropdown = false;
                console.log('Hiding dropdown on blur');
            } else {
                console.log('Focus moved to dropdown, keeping it open');
            }
        }, 300);
    }
    
    get optionsEmpty() {
        return !this.isLoading && this.options.length === 0 && this.searchTerm.length >= 2;
    }
    
    handleClear() {
        this.selectedValue = null;
        this.selectedName = '';
        this.searchTerm = '';
        this.options = [];
        this.showDropdown = false;
        
        // Dispatch event to clear (with bubbles and composed for datatable)
        this.dispatchEvent(new CustomEvent('change', {
            detail: {
                itemId: this.itemId,
                factorSetItemId: null,
                factorSetItemName: null
            },
            bubbles: true,
            composed: true
        }));
    }
}
