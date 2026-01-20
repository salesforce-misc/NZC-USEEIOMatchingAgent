# Net Zero Cloud Data Model Analysis
## For USEEIO Emissions Factor Matching Agent

## Key Objects

### 1. PcmtEmssnFctrSetItem (Procurement Emissions Factor Set Item)
**Purpose:** Stores emissions factors for different economic sectors (NAICS codes)

**Key Fields:**
- `EconomicSectorCode` (Text 255) - **NAICS code** - This is what we need to match against
- `EconomicSector` (Text 255) - Economic sector name/description
- `EconomicSectorCategory` (Text 255) - Category classification
- `TotScpe3EmssnPerMillionSpent` (Number 10,8) - **Emissions factor value** (tCO2e per million USD)
- `Scope3GhgCategory` (Picklist) - Scope 3 GHG category
- `Region` (Picklist) - Geographic region
- `PcmtEmssnFctrSetId` (Master-Detail) - Parent factor set
- Additional emission factor fields (Scope 1&2, Total, etc.)

**Role in Matching:** This is the **target** - we need to find the right `PcmtEmssnFctrSetItem` record for each spend record.

### 2. Scope3PcmtItem (Scope 3 Procurement Item)
**Purpose:** Stores customer spend data that needs emissions factor assignment

**Key Fields:**
- `SpendingCategory1` (Text 255) - **Primary spending category** - Main matching input
- `SpendingCategory2` (Text 255) - **Secondary spending category** - Additional context
- `SpendingCategory3` (Text 255) - **Tertiary spending category** - Additional context
- `PcmtEmssnFctrSetItemId` (Lookup) - **Target field to populate** - Links to matched factor
- `SupplierId` (Lookup) - Supplier information
- `ProductId` (Lookup) - Product information
- `Name` (Text 255) - Item name/description
- `Scope3GhgCategory` (Picklist) - Scope 3 category
- `SpentAmount` (Currency) - Spend amount
- `SpentDate` (Date) - Date of spend
- `CalculatedScope3EmssnInTco2e` (Formula) - Calculated emissions

**Role in Matching:** This is the **source** - we analyze the spending category fields to determine which `PcmtEmssnFctrSetItem` to link.

## Matching Challenge

**Problem:**
- Customers have **thousands of Scope3PcmtItem records**
- Each record has spending category data (Category1, 2, 3) that describes the purchase
- Need to match each spend record to the appropriate `PcmtEmssnFctrSetItem` based on NAICS code
- Manual matching is time-consuming and error-prone

**Solution:**
- Use **Generative AI** to analyze spending category text
- Understand the industry/sector from category descriptions
- Suggest appropriate `PcmtEmssnFctrSetItem` records (by NAICS code)
- Provide confidence scores and alternatives
- Allow bulk processing with review/override capabilities

## Matching Flow

```
Scope3PcmtItem (Spend Data)
    ↓
[SpendingCategory1, SpendingCategory2, SpendingCategory3]
    ↓
[AI/LLM Analysis]
    ↓
[Understand Industry/Sector from Category Text]
    ↓
[Match to NAICS Code]
    ↓
[Find PcmtEmssnFctrSetItem by EconomicSectorCode]
    ↓
[Suggest Match with Confidence Score]
    ↓
[User Review & Accept/Override]
    ↓
[Populate PcmtEmssnFctrSetItemId]
    ↓
[Calculate Emissions]
```

## Data Relationships

```
PcmtEmssnFctrSetItem
├── EconomicSectorCode (NAICS) ← Matching Key
├── TotScpe3EmssnPerMillionSpent (Factor Value)
└── ...

Scope3PcmtItem
├── SpendingCategory1, 2, 3 (Input for AI)
├── PcmtEmssnFctrSetItemId (Output - Lookup to PcmtEmssnFctrSetItem)
└── ...
```

## Questions for Clarification

1. **Spending Category Data Format:**
   - Are the spending category fields free-form text or structured/picklist values?
   - What kind of data do they typically contain? (e.g., "Office Supplies", "IT Services", "Raw Materials")
   - Are there common patterns or taxonomies customers use?

2. **Matching Scope:**
   - Should we also consider `SupplierId` or `ProductId` fields for additional context?
   - Are there other fields on Scope3PcmtItem that might help with matching?
   - Should `Scope3GhgCategory` be used as a filter/validation?

3. **PcmtEmssnFctrSetItem Data:**
   - How many `PcmtEmssnFctrSetItem` records typically exist? (hundreds? thousands?)
   - Are there multiple factor sets (via `PcmtEmssnFctrSetId`)?
   - Should `Region` be considered in matching?
   - Is `Scope3GhgCategory` on both objects used for validation?

4. **User Experience:**
   - Should this be **bulk processing** (process all records at once) or **interactive** (record-by-record)?
   - What's the expected volume? (hundreds, thousands, tens of thousands?)
   - Should there be **auto-approval** for high-confidence matches?
   - What confidence threshold for manual review?

5. **Matching Logic:**
   - Should we use **hierarchical NAICS matching** (6-digit → 5-digit → 4-digit fallback)?
   - How should we handle cases where spending categories are vague or don't clearly map to a NAICS code?
   - Should the AI suggest **multiple alternatives** or just the top match?

6. **Integration Points:**
   - Should this integrate with Net Zero Cloud's existing calculation engine?
   - Are there existing workflows/processes we should respect?
   - Should matches trigger any automated calculations or validations?

7. **Audit and Governance:**
   - Should we track **who made the match** (AI vs. user override)?
   - Should we log **confidence scores** for audit purposes?
   - Do we need **approval workflows** for certain types of matches?

## Proposed Architecture

Based on the design best practices and this data model:

### Components Needed:

1. **Apex Service Class**
   - `USEEIOMatchingService` - Core matching logic
   - Analyze spending categories
   - Call LLM for NAICS code suggestion
   - Find matching PcmtEmssnFctrSetItem records
   - Calculate confidence scores

2. **Lightning Web Component**
   - `useeioMatcher` - Interactive matching interface
   - Display spend records with suggested matches
   - Show confidence scores and alternatives
   - Allow bulk selection and approval
   - Override interface

3. **Screen Flow**
   - Guided matching workflow
   - Step-by-step process for users
   - Bulk processing with progress tracking
   - Review and commit interface

4. **Custom Metadata Types**
   - Matching rules and thresholds
   - LLM prompt templates
   - Confidence score thresholds
   - NAICS code mappings/aliases

5. **Batch/Queueable Apex** (if needed)
   - For processing large volumes
   - Async matching for thousands of records

---

*This analysis provides the foundation for designing the agentic matching experience.*
