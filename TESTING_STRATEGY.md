# Unit Testing Strategy - LLM Cost Prevention

## How Salesforce Unit Tests Work

### Test Context Isolation
- **Salesforce test context** (`@isTest` annotation) runs in a **separate, isolated environment**
- Tests **do NOT** have access to production data (unless using `@testSetup`)
- Tests **do NOT** make real callouts by default (prevents accidental external API calls)

### Callout Prevention in Tests

**By default, Salesforce prevents ALL callouts in test context:**

```apex
@isTest
static void testMethod() {
    // This will throw a CalloutException unless mocked
    // aiplatform.ModelsAPI.createGenerations(request); // ❌ Fails in test
}
```

**To allow callouts in tests, you MUST use `Test.setMock()`:**

```apex
@isTest
static void testMethod() {
    Test.setMock(HttpCalloutMock.class, new MockLLMResponse());
    // Now callouts are allowed, but use the mock instead
}
```

## Current Test Implementation

### ✅ **Tests Will NOT Call LLM (No Costs)**

Our current tests are **safe** and will **NOT incur LLM costs** because:

1. **No `Test.setMock()` calls** - Tests don't enable callouts
2. **Expected error handling** - Tests expect `NO_MATCH` status when LLM fails
3. **Test context isolation** - Salesforce prevents callouts automatically

### Current Test Behavior

```apex
@isTest
static void testMatchSpendItemToFactor_Success() {
    // This test will:
    // 1. Try to call LLMService.suggestNaicsCode()
    // 2. LLMService will attempt to call Models API
    // 3. Salesforce throws CalloutException (blocked in test context)
    // 4. LLMService catches exception and returns error response
    // 5. USEEIOMatchingService returns NO_MATCH status
    // 6. Test asserts NO_MATCH status ✅
    
    MatchingResult result = USEEIOMatchingService.matchSpendItemToFactor(testItem.Id);
    System.assertEquals('NO_MATCH', result.status); // ✅ Passes
}
```

**Result: No LLM call, no cost, test passes**

## Test Coverage Analysis

### Tests That DON'T Call LLM (Safe)

1. **`LLMServiceTest`**
   - Tests JSON parsing (`parseLLMResponse`)
   - Tests NAICS validation (`validateNaicsCode`)
   - Tests error handling (expects errors when LLM not configured)
   - ✅ **No callouts, no costs**

2. **`USEEIOMatchingServiceTest`**
   - Tests matching logic without LLM
   - Tests factor finding (`findMatchingFactors`)
   - Tests confidence calculation (`calculateConfidenceScore`)
   - Tests match application (`applyMatch`)
   - ✅ **No callouts, no costs**

3. **`KeywordMatchingServiceTest`**
   - Tests keyword extraction
   - Tests scoring logic
   - ✅ **No callouts, no costs**

### Tests That WOULD Call LLM (If Enabled)

Currently **NONE** - all tests are protected by Salesforce's default callout prevention.

## Future: Adding LLM Integration Tests

If you want to test the LLM integration **without incurring costs**, you should:

### Option 1: Mock the LLM Response (Recommended)

```apex
@isTest
static void testLLMIntegration_WithMock() {
    // Create a mock that returns a fake LLM response
    Test.setMock(HttpCalloutMock.class, new MockLLMResponse());
    
    // Now the test can call LLMService
    // But it will use the mock instead of real API
    LLMService.LLMResponse response = LLMService.suggestNaicsCode(
        'Accounting Services', null, null, new List<String>{'541211'}
    );
    
    // Assert mock response
    System.assertEquals('541211', response.suggestedNaicsCode);
    // ✅ No real LLM call, no cost
}
```

### Option 2: Test in Test Mode (Not Recommended)

```apex
@isTest
static void testLLMIntegration_RealCall() {
    // This would make a REAL LLM call and incur costs
    // NOT RECOMMENDED for unit tests
    Test.setMock(HttpCalloutMock.class, null); // Allow real callouts
    
    // Real LLM call happens here
    // ❌ Costs money, not recommended
}
```

## Best Practices

### ✅ DO:
- Test business logic (matching, scoring, validation)
- Test error handling
- Use mocks for external API calls
- Test edge cases and null handling

### ❌ DON'T:
- Make real LLM calls in unit tests
- Test LLM accuracy in unit tests (use integration tests)
- Skip mocking for external services
- Rely on external services being available

## Summary

**Your current tests are SAFE and will NOT incur LLM costs:**

1. ✅ Salesforce blocks callouts by default in test context
2. ✅ Tests don't use `Test.setMock()` to enable callouts
3. ✅ Tests expect and handle errors gracefully
4. ✅ All tests will pass without LLM being configured

**To test LLM integration later:**
- Use `Test.setMock()` with a mock response
- Create integration tests (separate from unit tests)
- Test in a sandbox with limited API usage

## Running Tests

```bash
# Run all tests (safe, no costs)
sf apex run test --class-names USEEIOMatchingServiceTest,LLMServiceTest,KeywordMatchingServiceTest

# Or in Developer Console:
# Test > New Run > Select classes > Run
```

**Expected Result:** All tests pass, no LLM calls, no costs ✅
