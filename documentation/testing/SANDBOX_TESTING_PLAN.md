# Sandbox Testing Plan for Bulk Matching Solution

## Recommended Approach: Use Full Copy Sandbox

### Why Full Copy Sandbox is Better

✅ **Advantages:**
1. **Real Data Available**: Already has `Scope3PcmtItem`, `Scope3PcmtSummary`, and `PcmtEmssnFctrSetItem` records
2. **Configuration Preserved**: Data Library (`USEEIO_Reference`) already indexed and configured
3. **Prompt Builder Templates**: `NAICS_Matching_Prompt` already set up
4. **Real-World Testing**: Can test with actual data volumes (thousands of items)
5. **Side-by-Side Comparison**: Can test both single-item and bulk solutions simultaneously
6. **Less Setup**: No need to recreate data or configuration

❌ **Scratch Org Disadvantages:**
- Would need to recreate all test data (hundreds/thousands of records)
- Would need to re-upload and index Data Library
- Would need to recreate Prompt Builder templates
- Doesn't have real-world data volumes
- More setup time

## Testing Strategy

### Phase 1: Safe Testing (No Production Data Risk)

1. **Create Test Scope3PcmtSummary**
   - Create a new `Scope3PcmtSummary` record specifically for testing
   - Link it to an existing `PcmtEmssnFctrSet` (or create a test one)
   - This keeps test data separate from production data

2. **Create Test Scope3PcmtItem Records**
   - Create 50-100 test `Scope3PcmtItem` records
   - Link them to the test `Scope3PcmtSummary`
   - Use varied spending categories to test different scenarios
   - **Do NOT modify existing production items**

3. **Deploy Bulk Matching Components**
   - Deploy all new classes, LWC, and custom fields
   - The single-item solution remains untouched
   - Both solutions can coexist

### Phase 2: Test Execution

1. **Test Single-Item Solution** (Verify it still works)
   - Use existing `Scope3PcmtItem` records
   - Verify the `useeioMatcher` LWC still works
   - Confirm no regressions

2. **Test Bulk Matching Solution**
   - Use the test `Scope3PcmtSummary` with test items
   - Click "Match All Items" button
   - Verify:
     - Batch processing works
     - Response caching works
     - Deduplication works
     - Review tracking works
     - UI updates correctly

3. **Test with Larger Dataset** (Optional)
   - If you have a `Scope3PcmtSummary` with many items that you're comfortable testing with
   - Test with 1,000+ items to verify performance
   - Monitor governor limits and processing time

## Deployment Steps

### Step 1: Connect to Sandbox

```bash
# If not already connected
sf org login web --alias sandbox --instance-url https://your-sandbox.salesforce.com

# Or if you have the sandbox alias already
sf org display --target-org sandbox
```

### Step 2: Deploy Components

```bash
# Deploy all components to sandbox
sf project deploy start --target-org sandbox

# Or deploy specific components
sf project deploy start --source-dir force-app/main/default/classes --target-org sandbox
sf project deploy start --source-dir force-app/main/default/lwc --target-org sandbox
sf project deploy start --source-dir force-app/main/default/objects --target-org sandbox
```

### Step 3: Verify Deployment

- Check that all classes deployed successfully
- Verify custom fields are created
- Confirm LWC components are available

### Step 4: Configure LWC on Record Page

1. Go to **Setup > Lightning App Builder**
2. Edit the `Scope3PcmtSummary` record page
3. Add the `bulkMatchingSummary` component
4. Save and activate

## Testing Checklist

### Pre-Testing Setup
- [ ] Connected to sandbox org
- [ ] All components deployed successfully
- [ ] Custom fields created (`Review_Status__c`, bulk matching fields on `Scope3PcmtSummary`)
- [ ] LWC component added to `Scope3PcmtSummary` record page
- [ ] Test `Scope3PcmtSummary` created
- [ ] Test `Scope3PcmtItem` records created (50-100 items)

### Functional Testing
- [ ] Single-item matching still works (no regression)
- [ ] Bulk matching button appears on `Scope3PcmtSummary`
- [ ] Button is disabled when no factor set
- [ ] Button is disabled when matching in progress
- [ ] Bulk matching starts successfully
- [ ] Status updates correctly (In Progress → Complete)
- [ ] Progress bar displays correctly
- [ ] Statistics display correctly (processed, matched, needs review)
- [ ] Cost optimization metrics display (cache hits, deduplicated, LLM calls)
- [ ] Items needing review appear in table
- [ ] Review progress bar displays
- [ ] Can mark items as reviewed
- [ ] Can mark items as skipped
- [ ] Reviewed/skipped items disappear from pending list
- [ ] Can resume review in new session

### Performance Testing
- [ ] Batch processing completes without errors
- [ ] No governor limit errors
- [ ] Processing time is reasonable
- [ ] Response caching works (check cache hit count)
- [ ] Deduplication works (check deduplicated count)
- [ ] LLM calls are minimized (check LLM calls count)

### Data Integrity
- [ ] No production data modified
- [ ] Test data isolated correctly
- [ ] Review status persists across sessions
- [ ] Match results saved correctly

## Rollback Plan

If something goes wrong:

1. **Remove LWC Component**
   - Remove `bulkMatchingSummary` from record page
   - Single-item solution remains functional

2. **Delete Test Data**
   - Delete test `Scope3PcmtSummary` and test items
   - Production data untouched

3. **Revert Deployment** (if needed)
   - Delete deployed classes/components
   - Original single-item solution unaffected

## Next Steps

1. **Connect to sandbox** (if not already)
2. **Deploy components** to sandbox
3. **Create test data** (test `Scope3PcmtSummary` with test items)
4. **Run tests** following the checklist above
5. **Report results** and iterate if needed

## Notes

- **Production Org**: Keep as-is with single-item solution
- **Sandbox**: Use for bulk matching testing
- **Test Data**: Create separate test records, don't modify production data
- **Both Solutions**: Can coexist - single-item on `Scope3PcmtItem`, bulk on `Scope3PcmtSummary`
