# Batch Size Explanation: 200 vs 50 Items

## Two Different Batch Size Concepts

### 1. **200 items per batch execution** (Salesforce Batch Apex Parameter)

**What it is:**
- This is the batch size parameter passed to `Database.executeBatch(batch, 200)`
- It tells Salesforce how to **chunk the total query results** before calling the `execute()` method

**How it works:**
```
Total items to process: 10,000

Salesforce automatically splits into chunks:
- Batch 1: Items 1-200    → execute() called with List of 200 items
- Batch 2: Items 201-400  → execute() called with List of 200 items
- Batch 3: Items 401-600   → execute() called with List of 200 items
- ... and so on
```

**Purpose:**
- Controls how many records Salesforce passes to each `execute()` call
- Larger batch size = fewer `execute()` calls, but more records per call
- Smaller batch size = more `execute()` calls, but fewer records per call

**Trade-offs:**
- **200 items**: Good balance - not too many records in memory, not too many execute() calls
- **100 items**: More execute() calls, but smaller memory footprint
- **500 items**: Fewer execute() calls, but larger memory footprint (may hit heap limits)

---

### 2. **Max 50 items per execution** (Internal Processing Limit)

**What it is:**
- This is an **internal limit** we set within the `execute()` method itself
- Even though Salesforce passes us 200 items, we only **process up to 50 of them** in a single execution

**Why we need it:**
- Each item might require **1 LLM API callout**
- Salesforce limit: **100 callouts per transaction**
- If we processed all 200 items, we could hit the callout limit
- By limiting to 50 items, we leave buffer room (50 callouts + 50 buffer = safe)

**How it works:**
```
Salesforce calls execute() with 200 items:

execute(List<Scope3PcmtItem> items) {
  for (Scope3PcmtItem item : items) {
    // Process item (might make LLM callout)
    
    if (itemsProcessedInBatch >= 50) {
      break; // Stop processing this batch
    }
  }
  
  // What happens to items 51-200?
  // They remain unprocessed in this execution
}
```

**The Problem:**
- If we only process 50 items out of 200, the remaining 150 items are **NOT automatically processed**
- They would be lost/skipped

**The Solution:**
We need to handle this properly. There are two approaches:

#### Option A: Process All 200, But Stop at Callout Limit (Current Implementation)
```apex
for (Scope3PcmtItem item : items) {
  if (Limits.getCallouts() >= 90) {
    break; // Stop when approaching limit
  }
  // Process item
}
```
- Processes as many as possible (up to 200) until hitting callout limit
- Remaining items in that batch are skipped (not ideal)

#### Option B: Use Smaller Batch Size (Recommended Fix)
```apex
// In BulkMatchingQueueable:
Database.executeBatch(batch, 50); // Match batch size to processing limit
```
- Pass 50 items to execute() instead of 200
- Process all 50 items in each execution
- No items skipped
- More execute() calls, but cleaner logic

---

## Visual Example

### Current Setup (200 batch size, 50 processing limit):

```
Total: 10,000 items

Salesforce chunks:
├─ execute() called with items 1-200
│  ├─ Process items 1-50 ✅
│  └─ Items 51-200 ❌ SKIPPED (not processed)
│
├─ execute() called with items 201-400
│  ├─ Process items 201-250 ✅
│  └─ Items 251-400 ❌ SKIPPED
│
└─ ... continues
```

**Problem:** Items 51-200, 251-400, etc. are never processed!

### Better Setup (50 batch size, 50 processing limit):

```
Total: 10,000 items

Salesforce chunks:
├─ execute() called with items 1-50
│  └─ Process items 1-50 ✅ (all processed)
│
├─ execute() called with items 51-100
│  └─ Process items 51-100 ✅ (all processed)
│
├─ execute() called with items 101-150
│  └─ Process items 101-150 ✅ (all processed)
│
└─ ... continues (all items processed)
```

**Better:** All items are processed!

---

## Recommended Fix

Change the batch size in `BulkMatchingQueueable` to match our processing limit:

```apex
// Current:
Database.executeBatch(batch, 200);

// Recommended:
Database.executeBatch(batch, 50); // Match processing limit
```

**Benefits:**
- All items are processed (no skipped items)
- Simpler logic (no need to track "remaining items")
- Still respects callout limits (50 items = max 50 callouts)
- More execute() calls, but that's fine (Batch Apex handles it)

**Trade-off:**
- More execute() calls (200 vs 50), but Batch Apex is designed for this
- Slightly more overhead, but ensures all items are processed

---

## Summary

| Concept | Value | Purpose | Set Where |
|---------|-------|---------|-----------|
| **Batch Size (Salesforce)** | 200 | How many items Salesforce passes to execute() | `Database.executeBatch(batch, 200)` |
| **Processing Limit (Internal)** | 50 | How many items we actually process per execute() | Inside `execute()` method |

**Current Issue:** Batch size (200) > Processing limit (50) = Some items skipped

**Recommended Fix:** Match batch size to processing limit (50 = 50)
