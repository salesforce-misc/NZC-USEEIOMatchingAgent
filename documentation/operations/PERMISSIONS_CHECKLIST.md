# Permissions Checklist

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

### Option 3: Use Permission Sets (Recommended)
A `Bulk_Matching_Access` permission set is included in the deployed metadata and covers all the object, field, and Apex class permissions listed above.

1. Go to **Setup > Users > Permission Sets**
2. Open **Bulk Matching Access**
3. Verify the permissions match those listed above
4. Assign the permission set to each user who needs access:
   ```bash
   sf org assign permset --name Bulk_Matching_Access --target-org <your-org-alias>
   ```

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
The LWCs call these Apex methods:

**`bulkMatchingSummary` (on Scope3PcmtSummary):**
- `USEEIOMatchingService.startBulkMatching`
- `USEEIOMatchingService.getMatchingStatus`
- `USEEIOMatchingService.getItemsNeedingReview`
- `USEEIOMatchingService.markItemsAsReviewed`
- `USEEIOMatchingService.getReviewStatistics`

**`useeioMatcher` (on Scope3PcmtItem):**
- `USEEIOMatchingService.matchSpendItemToFactor`
- `USEEIOMatchingService.applyMatchFromResult`

If these fail, check:
- Apex class access in your profile or permission set
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

### `bulkMatchingSummary` — "Run Bulk Matching" button

Disabled when any of the following are true:
- `isLoading` is true (button clicked, processing)
- `currentStatus === 'In Progress'` (a bulk job is already running)
- `hasFactorSet` is false (no `PcmtEmssnFctrId` on the summary record)

If `PcmtEmssnFctrId` is populated on the record but the button is still disabled, the wire service is likely failing to load the record — check FLS on `PcmtEmssnFctrId` and the object permissions on `Scope3PcmtSummary`.

### `useeioMatcher` — "Find Emissions Factor" button

Disabled when:
- `isLoading` is true (a match request is in flight)

The "Apply Match" button (shown after a result is returned) is additionally disabled when:
- No match result is available
- The result status is not `MATCHED` or `REQUIRES_REVIEW`

## Next Steps

1. Check browser console for errors (`Access Denied` = FLS issue; `INSUFFICIENT_ACCESS` = object or Apex class access)
2. Verify the `Bulk_Matching_Access` permission set is assigned to the user
3. If the bulk matching button is still disabled, confirm `PcmtEmssnFctrId` has a value on the summary record
4. If the single-item matcher shows no result, confirm the `Scope3PcmtItem` record has `SpendingCategory1` populated and the parent summary has a factor set configured
