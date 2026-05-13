# Response Caching Implementation Details

## Storage Location

**Yes, Response Caching is stored in a custom object within the customer's Salesforce org.**

### Custom Object: `LLM_Response_Cache__c`

This custom object would be created as part of the solution deployment and would store:
- **Category_Hash__c** (Text, Unique) - SHA-256 hash of the category combination
- **Suggested_NAICS__c** (Text) - The NAICS code suggested by LLM
- **Confidence__c** (Text) - HIGH, MEDIUM, or LOW
- **Reasoning__c** (Long Text Area) - LLM's reasoning for the match
- **Alternative_NAICS_Codes__c** (Text, comma-separated) - Alternative codes if any
- **Created_Date__c** (DateTime) - When the cache entry was created
- **Last_Used_Date__c** (DateTime) - When the cache was last accessed
- **Use_Count__c** (Number) - How many times this cache entry has been used
- **Factor_Set_ID__c** (Lookup to PcmtEmssnFctrSet) - Which factor set this applies to

## Data Persistence

### ✅ Data Remains in Customer's Org
- **Persistence**: Cache records persist indefinitely in the customer's Salesforce org
- **Ownership**: Data belongs to the customer, stored in their org
- **Retention**: Records remain until explicitly deleted by the customer
- **Backup**: Included in customer's Salesforce backups
- **Compliance**: Subject to customer's data retention policies

### Data Lifecycle

1. **Creation**: Cache entry created when LLM is first called for a category combination
2. **Usage**: Subsequent items with same categories retrieve from cache (no LLM call)
3. **Tracking**: `Last_Used_Date__c` and `Use_Count__c` updated on each access
4. **Retention**: Records persist until:
   - Customer manually deletes them
   - Automated cleanup job removes old/unused entries (if implemented)
   - Customer clears cache for specific factor sets

## Benefits of Persistent Storage

### 1. Cross-Session Persistence
```
Month 1: Process 10,000 items
  - 7,000 unique category combinations → LLM calls → Cached
  - 3,000 duplicates → Use cache

Month 2: Process another 10,000 items
  - 2,000 new combinations → LLM calls → Cached
  - 8,000 existing combinations → Use cache (no LLM calls!)
```

### 2. Knowledge Base Building
- Cache builds over time as a knowledge base
- Common category combinations become "learned"
- Reduces LLM costs as system matures

### 3. Audit Trail
- Track which category combinations have been processed
- See how often each combination appears
- Identify patterns in procurement data

## Cache Management Considerations

### When to Invalidate Cache

1. **Factor Set Changes**
   - If `PcmtEmssnFctrSet` is updated or replaced
   - NAICS codes in factor set change
   - **Solution**: Include `Factor_Set_ID__c` in cache key, or clear cache when factor set changes

2. **NAICS Code Updates**
   - If NAICS definitions change (rare, but possible)
   - **Solution**: Version cache entries or clear all cache

3. **Model Changes**
   - If LLM model is changed (e.g., GPT-4 → GPT-4.5)
   - **Solution**: Include model version in cache key, or clear cache

### Cache Cleanup Strategies

#### Option 1: Manual Cleanup
- Customer deletes cache records via UI or Data Loader
- Simple, but requires manual intervention

#### Option 2: Automated Cleanup
```apex
// Scheduled job to clean old/unused cache entries
public class LLMCacheCleanupBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Find entries not used in last 90 days
        Date cutoffDate = Date.today().addDays(-90);
        return Database.getQueryLocator([
            SELECT Id FROM LLM_Response_Cache__c
            WHERE Last_Used_Date__c < :cutoffDate
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<LLM_Response_Cache__c> scope) {
        delete scope;
    }
    
    public void finish(Database.BatchableContext bc) {
        // Log cleanup results
    }
}
```

#### Option 3: Size-Based Cleanup
- Keep top N most-used entries
- Remove least-used entries when cache exceeds size limit

## Security and Sharing

### Data Visibility
- Cache records follow standard Salesforce sharing rules
- Customer controls who can view/edit/delete cache records
- Can be restricted to specific profiles/roles

### Data Privacy
- Cache contains category text (may include sensitive information)
- Customer should review and apply appropriate field-level security
- Consider encrypting category hash if needed

## Storage Considerations

### Storage Usage Estimate

**Per Cache Entry:**
- Category_Hash__c: ~44 bytes (base64 SHA-256)
- Suggested_NAICS__c: ~10 bytes
- Confidence__c: ~10 bytes
- Reasoning__c: ~500-1000 bytes (average)
- Metadata fields: ~50 bytes
- **Total per entry**: ~600-1100 bytes

**For 10,000 unique category combinations:**
- Storage: ~6-11 MB
- Well within Salesforce data storage limits

**For 100,000 unique combinations:**
- Storage: ~60-110 MB
- Still manageable, but may want cleanup strategy

### Indexing
- Index `Category_Hash__c` (unique) for fast lookups
- Index `Factor_Set_ID__c` for filtering by factor set
- Index `Last_Used_Date__c` for cleanup queries

## Implementation Example

### Custom Object Metadata
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>LLM Response Cache</label>
    <pluralLabel>LLM Response Caches</pluralLabel>
    <nameField>
        <displayFormat>LLM-{Category_Hash__c}</displayFormat>
        <label>Cache Entry Name</label>
        <type>Text</type>
    </nameField>
    <fields>
        <fullName>Category_Hash__c</fullName>
        <label>Category Hash</label>
        <type>Text</type>
        <length>255</length>
        <unique>true</unique>
        <required>true</required>
        <description>SHA-256 hash of category combination (cat1|cat2|cat3)</description>
    </fields>
    <fields>
        <fullName>Suggested_NAICS__c</fullName>
        <label>Suggested NAICS Code</label>
        <type>Text</type>
        <length>6</length>
        <description>NAICS code suggested by LLM</description>
    </fields>
    <fields>
        <fullName>Confidence__c</fullName>
        <label>Confidence</label>
        <type>Picklist</type>
        <valueSet>
            <valueSetDefinition>
                <value>
                    <fullName>HIGH</fullName>
                    <label>High</label>
                </value>
                <value>
                    <fullName>MEDIUM</fullName>
                    <label>Medium</label>
                </value>
                <value>
                    <fullName>LOW</fullName>
                    <label>Low</label>
                </value>
            </valueSetDefinition>
        </valueSet>
    </fields>
    <fields>
        <fullName>Reasoning__c</fullName>
        <label>Reasoning</label>
        <type>LongTextArea</type>
        <length>32768</length>
        <visibleLines>5</visibleLines>
        <description>LLM's reasoning for the match</description>
    </fields>
    <fields>
        <fullName>Factor_Set_ID__c</fullName>
        <label>Factor Set</label>
        <type>Lookup</type>
        <referenceTo>PcmtEmssnFctrSet</referenceTo>
        <relationshipLabel>LLM Cache Entries</relationshipName>LLM_Response_Caches</relationshipName>
        <description>Factor set this cache entry applies to</description>
    </fields>
    <fields>
        <fullName>Last_Used_Date__c</fullName>
        <label>Last Used Date</label>
        <type>DateTime</type>
        <description>When this cache entry was last accessed</description>
    </fields>
    <fields>
        <fullName>Use_Count__c</fullName>
        <label>Use Count</label>
        <type>Number</type>
        <precision>18</precision>
        <scale>0</scale>
        <defaultValue>0</defaultValue>
        <description>Number of times this cache entry has been used</description>
    </fields>
</CustomObject>
```

## Summary

✅ **Yes, Response Caching is stored in the customer's Salesforce org**
- Custom object: `LLM_Response_Cache__c`
- Data persists indefinitely (unless deleted)
- Customer owns and controls the data
- Included in backups
- Subject to customer's data retention policies
- Can be managed via standard Salesforce tools (UI, Data Loader, etc.)

This gives customers:
- **Control**: They own the cache data
- **Persistence**: Cache builds over time
- **Cost Savings**: Reduces LLM calls as cache grows
- **Transparency**: Can see what's cached and when
