# Testing Without Data Library Indexing
## How to Test the Matching Agent While Data Library is Still Indexing

## Overview

Your Data Library (`USEEIO_Reference`) is still indexing, but you can start testing immediately! The code now includes a **test mode** that uses mock LLM responses based on keyword matching.

## How Test Mode Works

The `LLMService` class automatically uses **mock responses** when:
1. Running in a test class (`Test.isRunningTest()`)
2. Test mode is enabled via Custom Metadata or Custom Setting
3. The real LLM API is not available

Mock responses use simple keyword matching to suggest NAICS codes, allowing you to test the entire matching flow without waiting for indexing.

## Quick Start Testing

### Option 1: Test in Apex Anonymous Window (Easiest)

The code automatically uses mock responses when the real LLM isn't available. Just run:

```apex
// Get a real Scope3PcmtItem ID from your org
Id testItemId = 'a0X...'; // Replace with actual ID

// Test the matching service
MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);

// View results
System.debug('Status: ' + result.status);
System.debug('Recommended NAICS: ' + result.recommendedNaicsCode);
System.debug('Confidence: ' + result.confidenceScore);
System.debug('Reasoning: ' + result.reasoning);
System.debug('Factor ID: ' + result.recommendedFactorId);
```

**What happens:**
- Keyword pre-filtering runs normally (uses real data)
- LLM service uses mock response (keyword-based matching)
- Factor lookup runs normally (uses real data)
- Full matching flow is tested end-to-end

### Option 2: Test the Lightning Web Component

1. Navigate to a `Scope3PcmtItem` record in your org
2. Add the `useeioMatcher` component to the record page
3. Click **"Find Emissions Factor"**
4. The component will use mock responses automatically

### Option 3: Run Test Classes

The test classes already use mock responses automatically:

```bash
# Deploy and run tests
sf project deploy start --target-org BVJan2026
sf apex run test --class-names USEEIOMatchingServiceTest --target-org BVJan2026
```

## Mock Response Logic

The mock responses use keyword matching to suggest NAICS codes:

| Keywords | Suggested NAICS | Code |
|----------|----------------|------|
| accounting, bookkeeping, financial consulting | Accounting Services | 541211 |
| it consulting, software, computer programming | Custom Computer Programming Services | 541511 |
| office supplies, stationery, paper | Office Supplies and Stationery Stores | 453210 |
| legal, attorney, law | Offices of Lawyers | 541110 |
| marketing, advertising, promotion | Marketing Consulting Services | 541613 |
| Other | First candidate from pre-filtering | (varies) |

## Testing Different Scenarios

### Test 1: Accounting Services

```apex
// Create or find a Scope3PcmtItem with accounting-related categories
Scope3PcmtItem item = [SELECT Id FROM Scope3PcmtItem 
                       WHERE SpendingCategory1 LIKE '%accounting%' 
                       LIMIT 1];

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(item.Id);
// Should suggest NAICS 541211 with HIGH confidence
```

### Test 2: IT Services

```apex
// Find item with IT-related categories
Scope3PcmtItem item = [SELECT Id FROM Scope3PcmtItem 
                       WHERE SpendingCategory1 LIKE '%software%' 
                       OR SpendingCategory1 LIKE '%IT%'
                       LIMIT 1];

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(item.Id);
// Should suggest NAICS 541511 with HIGH confidence
```

### Test 3: Unknown Category

```apex
// Find item with unclear categories
Scope3PcmtItem item = [SELECT Id FROM Scope3PcmtItem 
                       WHERE SpendingCategory1 = 'Miscellaneous'
                       LIMIT 1];

MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(item.Id);
// May use first candidate from pre-filtering or return NO_MATCH
```

## What Gets Tested

Even with mock responses, you can test:

✅ **Keyword Pre-Filtering** - Uses real `PcmtEmssnFctrSetItem` data  
✅ **Factor Lookup** - Uses real factor set relationships  
✅ **Confidence Scoring** - Real calculation logic  
✅ **Error Handling** - Missing data, invalid codes, etc.  
✅ **UI Components** - Full user experience  
✅ **Data Validation** - NAICS code format, factor set relationships  

## Switching to Real LLM

Once your Data Library finishes indexing:

1. **Verify Indexing Complete:**
   - Go to Agentforce Studio → Data Library
   - Check that `USEEIO_Reference` shows "Indexed" status

2. **Test Mode is Automatically Disabled:**
   - The code only uses mock responses in test context or when explicitly enabled
   - In production, it will use the real Models API

3. **Test with Real LLM:**
   ```apex
   // The same code will now use real LLM
   MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItemId);
   ```

4. **Update Data Library Reference (if needed):**
   - The code references `USEEIO_Reference` automatically
   - If you need to specify it explicitly, update `LLMService.callLLMOpenConnector()`:
   ```apex
   request.grounding.knowledgeSourceId = 'USEEIO_Reference';
   ```

## Troubleshooting

### Issue: "Mock response not working"

**Solution:**
- Ensure you're in a test context or test mode is enabled
- Check that spending categories contain recognizable keywords
- Verify the test item has valid `ProcurementSummaryId` and factor set

### Issue: "Still getting real LLM errors"

**Solution:**
- The code will try real LLM first, then fall back to mock on error
- If you want to force mock mode, you can temporarily modify `isTestMode()` to always return `true`

### Issue: "Mock suggests wrong NAICS code"

**Solution:**
- Mock responses are simplified - they're just for testing the flow
- Once Data Library is indexed, real LLM will provide accurate matches
- You can extend `getMockResponse()` with more keyword patterns if needed

## Next Steps

1. ✅ **Test Now** - Use mock responses to test the full flow
2. ⏳ **Wait for Indexing** - Monitor Data Library status
3. ✅ **Test with Real LLM** - Once indexed, test with actual grounding
4. ✅ **Deploy to Production** - When everything works

---

**Note:** Mock responses are intentionally simple. The real LLM with Data Library grounding will provide much more accurate and nuanced matching once indexing completes!
