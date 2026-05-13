# Implementation Plan - v1 Proof of Concept
## USEEIO Emissions Factor Matching Agent

## Overview
Building a Lightning Web Component that helps users match Scope3PcmtItem records to PcmtEmssnFctrSetItem records using AI-powered NAICS code matching.

## Implementation Steps

### ✅ Step 1: Create Custom Fields on Scope3PcmtItem
**Purpose:** Store match results and metadata

**Fields to Create:**
1. `Match_Confidence_Score__c` - Number (3,2) - Confidence score 0.00-1.00
2. `Match_Reasoning__c` - Long Text Area - LLM reasoning explanation
3. `Match_Source__c` - Picklist - How match was determined (AI Suggested, User Override, Manual Selection)

**Status:** In Progress

### Step 2: Create Apex Service Classes
**Purpose:** Core business logic for matching

**Classes:**
1. `USEEIOMatchingService` - Main matching service
2. `KeywordMatchingService` - Pre-filtering logic
3. `LLMService` - LLM integration with Agentforce
4. Wrapper classes: `MatchingResult`, `AlternativeMatch`

### Step 3: Create Lightning Web Component
**Purpose:** User interface for matching

**Component:** `useeioMatcher`
- Embedded on Scope3PcmtItem record page
- Displays spending categories
- "Find Emissions Factor" button
- Shows match results with confidence
- Allows apply/override

### Step 4: Create Test Classes
**Purpose:** Ensure code quality and coverage

**Test Classes:**
- `USEEIOMatchingServiceTest`
- `KeywordMatchingServiceTest`
- `LLMServiceTest`
- `useeioMatcherTest`

### Step 5: Deploy and Test
**Purpose:** Validate in Salesforce org

**Tasks:**
- Deploy to org
- Test with real data
- Verify LLM integration
- Test user experience

## Current Step: Step 1 - Custom Fields

Let's start by creating the custom fields on Scope3PcmtItem.
