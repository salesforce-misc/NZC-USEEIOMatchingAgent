# Permissions Checklist for Bulk Matching LWC

## Issue: Buttons are Disabled

The LWC buttons are disabled based on JavaScript logic, not just permissions. However, missing permissions can cause the data to not load, which keeps buttons disabled.

## Required Permissions

### 1. Object Permissions
Your user profile needs:
- ✅ **Read** access to `Scope3PcmtSummary`
- ✅ **Read** access to `Scope3PcmtItem`
- ✅ **Read** access to `PcmtEmssnFctrSetItem`
- ✅ **Read** access to `LLM_Response_Cache__c` (custom object)
- ✅ **Edit** access to `Scope3PcmtSummary` (to update status fields)
- ✅ **Edit** access to `Scope3PcmtItem` (to update match results and review status)

### 2. Field-Level Security (FLS) - Critical!

Your user profile needs **Read** access to these custom fields on `Scope3PcmtSummary`:
- ✅ `Bulk_Matching_Status__c`
- ✅ `Bulk_Matching_Job_Id__c`
- ✅ `Bulk_Matching_Completed_Date__c`
- ✅ `Bulk_Matching_Items_Processed__c`
- ✅ `Bulk_Matching_Items_Matched__c`
- ✅ `Bulk_Matching_Items_Needing_Review__c`
- ✅ `Bulk_Matching_Cache_Hits__c`
- ✅ `Bulk_Matching_Deduplicated__c`
- ✅ `Bulk_Matching_LLM_Calls__c`
- ✅ `Bulk_Matching_Cost_Saved__c`
- ✅ `PcmtEmssnFctrId` (standard field - should already have access)

Your user profile needs **Read** and **Edit** access to these custom fields on `Scope3PcmtItem`:
- ✅ `Review_Status__c` (Read + Edit)
- ✅ `Match_Confidence_Score__c` (Read)
- ✅ `Match_Reasoning__c` (Read)
- ✅ `Match_Source__c` (Read)
- ✅ `PcmtEmssnFctrSetItemId` (Read + Edit)

### 3. Apex Class Access

Your user profile needs access to these Apex classes:
- ✅ `USEEIOMatchingService`
- ✅ `BulkMatchingQueueable`
- ✅ `BulkMatchingBatch`
- ✅ `LLMResponseCache`
- ✅ `LLMService`
- ✅ `KeywordMatchingService`
- ✅ `MatchingResult`
- ✅ `BulkMatchingStatus`
- ✅ `BulkMatchingResult`
- ✅ `AlternativeMatch`

### 4. Custom Object Permissions

Your user profile needs:
- ✅ **Read** access to `LLM_Response_Cache__c`
- ✅ **Create** access to `LLM_Response_Cache__c`
- ✅ **Edit** access to `LLM_Response_Cache__c`

## How to Check/Set Permissions

### Option 1: Use System Administrator Profile (Easiest)
If you're using a System Administrator profile, you should already have all permissions. If buttons are still disabled, it's likely a data/loading issue, not permissions.

### Option 2: Check Profile Permissions
1. Go to **Setup > Users > Profiles**
2. Select your profile
3. Check **Object Settings** for each object listed above
4. Check **Field-Level Security** for each custom field

### Option 3: Use Permission Sets (Recommended for Testing)
1. Go to **Setup > Users > Permission Sets**
2. Create a new Permission Set: "Bulk Matching Access"
3. Add Object Permissions for all objects listed above
4. Add Field Permissions for all custom fields listed above
5. Add Apex Class Access for all classes listed above
6. Assign the Permission Set to your user

## Debugging Steps

### Step 1: Check Browser Console
1. Open the record page with the LWC
2. Press F12 to open Developer Tools
3. Go to **Console** tab
4. Look for JavaScript errors (red text)
5. Common errors:
   - `Access Denied` = Field-Level Security issue
   - `INSUFFICIENT_ACCESS` = Object or Apex class access issue
   - `Cannot read property 'data' of undefined` = Wire service not loading

### Step 2: Check Wire Service Data
The LWC uses `@wire(getRecord)` to load the `Scope3PcmtSummary` record. If this fails:
- Check FLS on `PcmtEmssnFctrId` field
- Check object permissions on `Scope3PcmtSummary`
- Check record sharing (if using sharing rules)

### Step 3: Check Apex Method Access
The LWC calls these Apex methods:
- `USEEIOMatchingService.startBulkMatching`
- `USEEIOMatchingService.getMatchingStatus`
- `USEEIOMatchingService.getItemsNeedingReview`
- `USEEIOMatchingService.markItemsAsReviewed`

If these fail, check:
- Apex class access in your profile
- Method visibility (should be `public` with `@AuraEnabled`)

## Quick Fix: Grant All Permissions

If you have admin access, the quickest way is to:

1. **Assign System Administrator Profile** (if not already)
   - Setup > Users > Users
   - Edit your user
   - Set Profile to "System Administrator"

2. **Or Create Permission Set** (if you want to keep current profile):
   ```bash
   # I can help you create a permission set via CLI if needed
   ```

## Why Buttons Are Disabled

The "Match All Items" button is disabled when:
- `isLoading` is true (button clicked, processing)
- `currentStatus === 'IN_PROGRESS'` (matching already running)
- `hasFactorSet` is false (no `PcmtEmssnFctrId` on the record)

The `hasFactorSet` getter checks:
```javascript
get hasFactorSet() {
    return getFieldValue(this.wiredSummary?.data, PCMT_EMSSN_FCTR_ID_FIELD) != null;
}
```

If `wiredSummary?.data` is null or undefined, or if `PcmtEmssnFctrId` is null, the button stays disabled.

## Next Steps

1. Check browser console for errors
2. Verify you have System Administrator profile (or all permissions listed above)
3. If still disabled, check if `PcmtEmssnFctrId` field has a value on the record
4. Check if wire service is loading data (inspect `wiredSummary` in browser console)
