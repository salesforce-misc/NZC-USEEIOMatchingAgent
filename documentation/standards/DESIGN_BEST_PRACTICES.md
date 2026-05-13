# Design Best Practices for LLM-Based Salesforce Agentic Experiences
## Based on Repository Patterns and Salesforce Net Zero Cloud Guidelines

This document synthesizes best practices for building agentic experiences in Salesforce, particularly for LLM-based matching and recommendation systems like the USEEIO emissions factor matching agent.

## Core Design Principles

### 1. Declarative-First Approach
- **Use Flows over Apex** wherever possible for business logic
- **Screen Flows** for guided user experiences
- **Autolaunched Flows** for background processing
- **Process Builder / Flow Triggers** for automation
- Only use Apex when declarative options are insufficient

### 2. Modularity and Reusability
- **Service Layer Pattern**: Separate business logic into reusable Apex service classes
- **Base Components**: Create foundational LWC components that can be extended
- **Utility Classes**: Shared functionality across multiple components
- **Custom Metadata Types**: Configuration-driven design for mappings and rules

### 3. Separation of Concerns
- **UI Layer (LWC)**: Presentation, user interactions, data display
- **Business Logic (Apex Services)**: Matching algorithms, calculations, validations
- **Data Layer (Objects)**: Data model, relationships, field definitions
- **Configuration Layer (Metadata)**: Rules, mappings, thresholds

### 4. Human-in-the-Loop Design
- **Suggest, Don't Auto-Apply**: Always present recommendations for user review
- **Confidence Scores**: Display match confidence levels
- **Override Capabilities**: Allow users to correct or refine matches
- **Audit Trail**: Log all decisions, overrides, and user actions
- **Transparency**: Show reasoning, data sources, and assumptions

### 5. Rule-Based Validation and Guardrails
- **Deterministic Rules**: Validate LLM outputs with business rules
- **Structured Outputs**: Use JSON schemas for LLM responses
- **Validation Layer**: Programmatic checks before applying matches
- **Exception Handling**: Graceful degradation when matches fail
- **Thresholds**: Confidence levels for auto-approval vs. manual review

### 6. Metadata-Driven Configuration
- **Custom Metadata Types**: Store matching rules, thresholds, mappings
- **Custom Settings**: Frequently accessed configuration
- **Hierarchical Custom Settings**: Environment-specific overrides
- **No Hardcoding**: All business rules configurable without code deployment

### 7. Bulkification and Performance
- **Bulk Processing**: All code handles 200+ records
- **Batch Apex**: For large data volumes
- **Queueable**: For async processing
- **SOQL Optimization**: Selective queries, indexed fields
- **Caching**: Platform Cache for reference data
- **Pagination**: For UI components with large datasets

### 8. Error Handling and Logging
- **Comprehensive Try-Catch**: All Apex methods with error handling
- **User-Friendly Messages**: Clear, actionable error messages
- **Error Logging**: Track errors for debugging and improvement
- **Fault Paths**: Flows include error handling paths
- **Retry Logic**: For transient failures

### 9. Security and Governance
- **CRUD/FLS Checks**: Always verify object and field permissions
- **Sharing Rules**: Appropriate data visibility
- **Least Privilege**: Agents act with minimal required permissions
- **Supervisory Controls**: Human approval for high-risk actions
- **Field-Level Security**: Protect sensitive data

### 10. Auditability and Traceability
- **Decision Logging**: Record all agent decisions and reasoning
- **Override Tracking**: Who changed what and when
- **Source Attribution**: Track data sources and versions
- **Version Control**: Reference dataset versions
- **Change History**: Track all modifications

## Agentic Experience Patterns

### Pattern 1: Intelligent Matching with LLM Integration

**Components:**
- **LLM Open Connector / BYO LLM**: Integrate LLM of choice via prompts
- **Prompt Templates**: Structured prompts with context
- **RAG (Retrieval-Augmented Generation)**: Include NAICS definitions, sector mappings in context
- **Structured Outputs**: JSON schemas for LLM responses
- **Validation Layer**: Rule-based validation of LLM outputs

**Flow:**
1. User provides spend data (with or without NAICS codes)
2. Agent/LLM analyzes spend description, vendor, category
3. LLM suggests NAICS code and emissions factor mapping
4. Validation layer checks against business rules
5. Present suggestions to user with confidence scores
6. User reviews, accepts, or overrides
7. Log decision and reasoning

### Pattern 2: Hierarchical Matching Fallback

**Logic:**
1. Attempt exact NAICS code match (6-digit)
2. If no match, try parent level (5-digit industry)
3. If still no match, try 4-digit industry group
4. If still no match, try 3-digit subsector
5. If still no match, flag for manual review

**Implementation:**
- Apex service class with recursive matching logic
- Custom Metadata Type for matching rules
- Configurable fallback thresholds

### Pattern 3: Guided Review Interface

**Components:**
- **Screen Flow**: Step-by-step guided experience
- **LWC Components**: Interactive lists, search, filters
- **Confidence Indicators**: Visual indicators of match quality
- **Comparison View**: Show alternative matches
- **Context Display**: NAICS definitions, factor sources, calculations

**User Experience:**
1. Upload/select spend data
2. View auto-matched results grouped by confidence
3. Review unmatched or low-confidence items
4. Manual override interface with search
5. Validate and commit matches
6. View aggregated emissions results

### Pattern 4: Feedback and Learning Loop

**Components:**
- **Override Tracking**: Log user corrections
- **Pattern Recognition**: Identify common override patterns
- **Rule Refinement**: Update matching rules based on feedback
- **Metrics Dashboard**: Track match accuracy, override rates
- **Continuous Improvement**: Retune prompts and thresholds

## Net Zero Cloud Integration Patterns

### Leverage Existing Objects
- **No New Objects**: Use existing Net Zero Cloud data model
- **Extend Where Possible**: Add fields to existing objects
- **Relationships**: Link to existing spend, supplier, emission factor objects
- **Calculations**: Integrate with Net Zero Cloud calculation engine

### Data Model Alignment
- **Spend Records**: Map to existing procurement/spend objects
- **Emission Factors**: Use existing emission factor objects or reference datasets
- **Scope 3 Categories**: Align with Net Zero Cloud Scope 3 taxonomy
- **USEEIO Integration**: Leverage Net Zero Cloud's built-in USEEIO dataset

### UI/UX Integration
- **Follow Net Zero Cloud Patterns**: Consistent navigation and styling
- **Dashboard Integration**: Embed in Net Zero Cloud dashboards
- **Reporting**: Use Net Zero Cloud reporting capabilities
- **Branding**: Match Net Zero Cloud visual design

## Technical Architecture Patterns

### Service Layer

```
Spend Record → Matching Service → Validation → User Review → Emission Factor
     ↓              ↓                ↓            ↓              ↓
  NAICS Code    LLM/Agent      Business Rules  LWC/Flow    Calculation
```

### Component Structure

```
┌─────────────────────────────────────────────────┐
│           Lightning Web Component (UI)          │
│  - Spend data display                            │
│  - Match suggestions                             │
│  - Override interface                            │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│              Screen Flow (Orchestration)          │
│  - Step-by-step guidance                         │
│  - Decision points                               │
│  - Error handling                                │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│         Apex Service (Business Logic)            │
│  - Matching algorithm                            │
│  - LLM integration                               │
│  - Validation rules                              │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│      Custom Metadata (Configuration)             │
│  - Matching rules                                │
│  - Thresholds                                   │
│  - NAICS mappings                                │
└──────────────────────────────────────────────────┘
```

## LLM Integration Best Practices

### Prompt Design
- **Structured Context**: Include NAICS definitions, sector mappings
- **Few-Shot Examples**: Provide examples of correct mappings
- **Output Schema**: Define expected JSON structure
- **Error Handling**: Instruct LLM on how to handle uncertainty

### Validation Strategy
- **Schema Validation**: Verify JSON structure matches expected format
- **Business Rules**: Check against allowed NAICS codes, factor ranges
- **Confidence Thresholds**: Require minimum confidence for auto-approval
- **Fallback Logic**: Manual review for low-confidence matches

### Cost and Performance
- **Caching**: Cache common mappings to reduce LLM calls
- **Batch Processing**: Group similar requests
- **Rate Limiting**: Respect API limits
- **Error Retry**: Handle transient failures gracefully

## Data Quality and Governance

### Reference Data Management
- **Authoritative Sources**: Single source of truth for NAICS codes, factors
- **Version Control**: Track reference dataset versions
- **Update Process**: Controlled process for updating mappings
- **Data Stewardship**: Clear ownership and maintenance responsibilities

### Matching Quality
- **Confidence Scoring**: Quantify match certainty
- **Validation Rules**: Ensure matches make business sense
- **Exception Lists**: Handle known edge cases
- **Quality Metrics**: Track accuracy, override rates, time to match

## User Experience Principles

### Clarity
- **Clear Labels**: Descriptive field labels and help text
- **Visual Indicators**: Icons, colors for status and confidence
- **Contextual Help**: Tooltips, definitions, examples
- **Progress Indicators**: Show completion status

### Efficiency
- **Bulk Actions**: Process multiple records at once
- **Keyboard Shortcuts**: Power user features
- **Smart Defaults**: Pre-fill based on patterns
- **Quick Actions**: Common tasks easily accessible

### Transparency
- **Show Reasoning**: Explain why matches were suggested
- **Source Attribution**: Show data sources and versions
- **Alternative Options**: Present other possible matches
- **Audit Trail**: Visible history of changes

## Testing Strategy

### Unit Tests
- **Service Classes**: Test matching logic, validation rules
- **Edge Cases**: Handle missing data, invalid codes, boundary conditions
- **Error Scenarios**: Test error handling and recovery

### Integration Tests
- **End-to-End Flows**: Test complete user journeys
- **LLM Integration**: Mock LLM responses for testing
- **Data Quality**: Test with real-world data samples

### User Acceptance Testing
- **Usability Testing**: Validate user experience
- **Performance Testing**: Large datasets, bulk operations
- **Security Testing**: Permission checks, data access

## Deployment and Maintenance

### Version Control
- **Git Workflow**: Feature branches, code reviews
- **Metadata Tracking**: All customizations in version control
- **CI/CD**: Automated testing and deployment

### Change Management
- **Configuration Changes**: Use Custom Metadata for non-code changes
- **Data Migration**: Scripts for reference data updates
- **User Communication**: Notify users of changes affecting their work

### Monitoring
- **Error Tracking**: Monitor exceptions and failures
- **Performance Metrics**: Track processing times, API usage
- **User Analytics**: Usage patterns, common overrides
- **Quality Metrics**: Match accuracy, user satisfaction

## Key Takeaways for USEEIO Matching Agent

1. **Use existing Net Zero Cloud objects** - don't create new ones
2. **Declarative-first** - Flows and LWC over Apex where possible
3. **Human-in-the-loop** - always present suggestions for review
4. **Metadata-driven** - all rules and mappings configurable
5. **Hierarchical matching** - fallback from 6-digit to broader codes
6. **LLM integration** - use LLM Open Connector with validation
7. **Audit everything** - track all decisions and overrides
8. **Performance matters** - bulkification, caching, async processing
9. **Security first** - CRUD/FLS checks, least privilege
10. **Continuous improvement** - learn from user feedback

---

*These design best practices should guide the development of the USEEIO Matching Agent in Salesforce Net Zero Cloud, ensuring a robust, maintainable, and user-friendly agentic experience.*
