# Salesforce Development Best Practices
## For LLM-Based and Agentic Experiences

Based on Salesforce development best practices for building intelligent, agentic experiences.

## Core Principles

### 1. Separation of Concerns
- **Apex Classes**: Business logic, data processing, API integrations
- **Lightning Web Components (LWC)**: UI/UX, user interactions
- **Flows**: Declarative automation, user-guided processes
- **Custom Objects**: Data model foundation
- **Custom Metadata**: Configuration and mappings

### 2. Data Model Design
- Use **Custom Objects** for domain-specific data (NAICS codes, USEEIO factors, spend records)
- Use **Custom Metadata Types** for configuration and crosswalks (NAICS to BEA mappings)
- Leverage **External Objects** or **Platform Events** for real-time data if needed
- Design for **scalability** - consider large datasets and bulk operations

### 3. Apex Best Practices
- **Service Layer Pattern**: Separate service classes from controllers
- **Exception Handling**: Comprehensive try-catch blocks with meaningful error messages
- **Bulkification**: All code must handle 200+ records
- **Governor Limits**: Be mindful of SOQL queries, DML operations, CPU time
- **Test Coverage**: Minimum 75% coverage, aim for 90%+
- **Async Processing**: Use `@future`, Queueable, or Batchable for long-running operations

### 4. Lightning Web Component Best Practices
- **Wire Services**: Use `@wire` for reactive data fetching
- **Imperative Calls**: Use for user-triggered actions
- **Error Handling**: Display user-friendly error messages
- **Loading States**: Show spinners/loading indicators
- **Accessibility**: Follow WCAG guidelines
- **Performance**: Lazy load data, pagination for large lists

### 5. Flow Best Practices
- **Screen Flows**: For guided user experiences
- **Autolaunched Flows**: For background processing
- **Decision Elements**: Clear branching logic
- **Variables**: Use appropriate data types
- **Error Handling**: Include fault paths
- **Documentation**: Clear element labels and descriptions

### 6. Integration Patterns
- **REST APIs**: For external USEEIO data sources
- **Callouts**: Use Named Credentials for secure endpoints
- **Platform Events**: For real-time updates
- **Scheduled Jobs**: For data synchronization

### 7. Security
- **Sharing Rules**: Appropriate data visibility
- **Field-Level Security**: Protect sensitive data
- **Apex Sharing**: Enforce sharing in code when needed
- **CRUD/FLS Checks**: Always check object and field permissions

### 8. Testing
- **Unit Tests**: Test all Apex classes
- **Integration Tests**: Test end-to-end flows
- **Test Data Factory**: Reusable test data creation
- **Assertions**: Verify expected outcomes

### 9. Documentation
- **ApexDoc**: Document all public methods
- **Code Comments**: Explain complex logic
- **README**: Project overview and setup
- **User Guides**: For end-user features

### 10. Version Control
- **Git Workflow**: Feature branches, pull requests
- **Deployment**: Use change sets or SFDX
- **Metadata**: Track all customizations
- **CI/CD**: Automated testing and deployment

## Agentic Experience Patterns

### Pattern 1: Intelligent Matching
- Use **Apex Services** for matching logic
- **LWC** for interactive search and selection
- **Flow** for guided matching workflows
- **Custom Metadata** for matching rules and weights

### Pattern 2: Data Enrichment
- **Batch Apex** for bulk data processing
- **Queueable** for async enrichment
- **Platform Events** for real-time updates
- **External Objects** for external data sources

### Pattern 3: User Guidance
- **Screen Flows** for step-by-step guidance
- **LWC** for rich interactive experiences
- **Tooltips and Help Text** for context
- **Validation Rules** for data quality

### Pattern 4: Recommendations
- **Apex Services** for recommendation algorithms
- **LWC** for displaying recommendations
- **Custom Settings** for recommendation parameters
- **Analytics** for tracking user selections

## Net Zero Cloud Specific Considerations

### Integration Points
- **Carbon Accounting Objects**: Leverage existing Net Zero Cloud objects
- **Emission Factors**: Store USEEIO factors as emission factors
- **Spend Data**: Map to Net Zero Cloud spend/category objects
- **Calculations**: Integrate with Net Zero Cloud calculation engine

### Data Model Extensions
- Extend Net Zero Cloud objects where possible
- Create related custom objects for USEEIO-specific data
- Use relationships to link spend → NAICS → USEEIO factors

### User Experience
- Follow Net Zero Cloud UI patterns
- Integrate with existing Net Zero Cloud navigation
- Use Net Zero Cloud branding and styling
- Leverage Net Zero Cloud reporting capabilities

## Code Organization

```
force-app/main/default/
├── classes/
│   ├── services/          # Business logic services
│   ├── controllers/       # LWC controllers
│   ├── batch/            # Batch processing
│   ├── queueable/        # Async processing
│   └── test/             # Test classes
├── lwc/
│   ├── useeioMatcher/    # Main matching component
│   ├── naicsSearch/      # NAICS code search
│   ├── factorDisplay/   # Display emissions factors
│   └── spendAnalyzer/   # Spend data analysis
├── objects/
│   ├── NAICS_Code__c/   # NAICS code object
│   ├── USEEIO_Factor__c/ # USEEIO emissions factors
│   └── Spend_Mapping__c/ # Spend to NAICS mapping
├── flows/
│   ├── Match_Spend_to_NAICS/ # Guided matching flow
│   └── Calculate_Emissions/ # Emissions calculation
└── metadata/
    └── NAICS_BEA_Crosswalk/ # NAICS to BEA mapping
```

## Performance Optimization

1. **SOQL Optimization**
   - Use selective WHERE clauses
   - Limit fields in SELECT
   - Use indexes on filter fields
   - Avoid SOQL in loops

2. **Caching**
   - Use Custom Settings for frequently accessed config
   - Cache metadata in static variables
   - Use Platform Cache for large datasets

3. **Bulk Processing**
   - Process records in batches
   - Use Database methods with allOrNone=false
   - Implement retry logic for failures

4. **UI Performance**
   - Lazy load components
   - Paginate large lists
   - Use wire services efficiently
   - Minimize component re-renders

## Error Handling Patterns

```apex
// Service Layer Pattern
public class USEEIOMatchingService {
    public static MatchingResult matchSpendToNAICS(SpendRecord spend) {
        try {
            // Matching logic
            return result;
        } catch (Exception e) {
            // Log error
            // Return user-friendly error
            throw new MatchingException('Unable to match spend record: ' + e.getMessage());
        }
    }
}

// Custom Exception
public class MatchingException extends Exception {}
```

## Testing Patterns

```apex
@isTest
private class USEEIOMatchingServiceTest {
    @testSetup
    static void setupTestData() {
        // Create test data
    }
    
    @isTest
    static void testMatchingSuccess() {
        // Test successful matching
    }
    
    @isTest
    static void testMatchingFailure() {
        // Test error handling
    }
}
```

---

*These best practices should guide the development of the USEEIO Matching Agent in Salesforce Net Zero Cloud.*
