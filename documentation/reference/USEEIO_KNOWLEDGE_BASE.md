# USEEIO v2.0 Knowledge Base
## Based on Ingwersen et al. (2022)

## Overview

**USEEIO v2.0** (US Environmentally-Extended Input-Output Model v2.0) is an environmental-economic model of US goods and services that enables comprehensive life cycle assessment, environmental footprinting, national prioritization, and related sustainability applications.

**Reference:** Ingwersen, W. W., Li, M., Young, B., Vendries, J., & Birney, C. (2022). USEEIO v2.0, The US Environmentally-Extended Input-Output Model v2.0. *Scientific Data*, 9:194. https://doi.org/10.1038/s41597-022-01293-7

## Key Model Characteristics

### Structure
- **Model Type:** Commodity-based model
- **Commodities:** 411 commodity categories
  - Based on BEA 2012 Detail IO tables (405 commodities)
  - One BEA commodity split into 7 more specific commodities (404 + 7 = 411)
- **Geographic Scope:** Single region model covering 50 US states
  - US Territories and Tribal Lands not included
  - Can separate domestic vs. rest of world (RoW) impacts
- **Base Year:** 2012 (USD)
  - Economic data: 2012 BEA Detail Make and Use Tables
  - Environmental data: More recent years (2014-2017) where available

### Model Versioning
- **Technical Name:** USEEIO v2.0.1--411
- **Referred to as:** v2.0
- **Predecessors:**
  - v1.0 (2017): 385 commodities, 2007 IO data, mixed-year environmental data (latest 2013)
  - v1.1: Additional satellite tables and methodological updates
  - v1.2: New satellite tables for commercial waste
  - v2.0 GHG models: Series of models for Supply Chain Greenhouse Gas Emission Factors

## Core Capabilities

USEEIO v2.0 can calculate:
1. **Environmental Impacts** - Full suite of potential life cycle impacts
2. **Resource Use** - Consumption of natural resources
3. **Waste Generation** - Various waste streams
4. **Economic Impacts** - Economic flow analysis
5. **Employment** - Job creation and labor metrics

## Novel Methodological Elements (v2.0)

### 1. Waste Sector Disaggregation
- More detailed breakdown of waste-related sectors compared to v1 models

### 2. Final Demand Vectors
- **US Consumption:** Final demand for US consumption patterns
- **US Production:** Final demand for US production patterns
- Enables analysis of consumption vs. production-based impacts

### 3. Domestic Model Variant
- Separates domestic and foreign impacts
- Allows for analysis of:
  - Domestic supply chain impacts
  - Imported goods/services impacts
  - Trade-related environmental flows

### 4. Price Adjustment Matrices
- **Producer Price:** Price reflecting industry's cost to produce (including commodity taxes)
- **Purchaser Price:** Price at point of sale (includes margins)
- **Price Conversion:** Matrices for converting between price types
- **Year Adjustment:** Conversion to various US dollar years

## Data Sources

### Economic Data
- **Primary Source:** 2012 BEA Detail Make and Use Tables Before Redefinitions in Producer's Price
- **Supporting Data:**
  - Gross Industry Output (2002-2017)
  - Gross Output Chain-Type Price Index (2002-2017)
  - 2012 Margins data (producer to purchaser price differences)
  - 2012 Import Matrix

### Environmental & Employment Data
National totals of flows by industries covering:

#### Resource Use
- Water withdrawals
- Land use
- Mineral extraction
- Energy consumption

#### Environmental Releases
- **Air Emissions:**
  - Greenhouse gases (GHG)
  - Criteria air pollutants
  - Hazardous air emissions
- **Water Releases:**
  - Point source industrial releases to water
- **Soil Releases:**
  - Point source releases to ground

#### Waste Generation
- Commercial waste
- Industrial waste
- Hazardous waste

#### Socioeconomic
- Employment (by industry)
- Value added

### Data Coverage
- Equivalent coverage to v1.2
- Updated and improved data for:
  - Water withdrawals
  - Criteria and hazardous air emissions
  - Point source releases (ground and water)
  - Greenhouse gases
  - Land use
  - Employment
  - Value added

## Model Construction

### Software Infrastructure
- Built using improved technical infrastructure (v2 generation)
- **Reproducible:** All model datasets can be reproduced with open source software packages
- **Primary Tools:**
  - `useeior` - R package for model construction
  - `flowsa` - Flow data processing
  - `LCIA formatter` - Life cycle impact assessment formatting

### Key Matrices
- **Direct Requirements Matrix (A):** Direct input requirements per unit output
- **Total Requirements Matrix (L):** Total (direct + indirect) requirements
- **Direct Impact Coefficients (D):** Direct environmental impacts per unit output
- **Total Impact Coefficients (N):** Total (direct + indirect) environmental impacts
- **H_r and H_f Matrices:** Additional transformation matrices

### Model Variants
- **Standard Model:** Full model with all commodities
- **Domestic Model:** Separates domestic vs. foreign impacts
- **Price Variants:** Producer price and purchaser price versions

## Applications

### Primary Use Cases
1. **Life Cycle Assessment (LCA)**
   - Product-level environmental impact assessment
   - Supply chain impact analysis

2. **Environmental Footprinting**
   - Carbon footprinting
   - Water footprinting
   - Ecological footprinting

3. **National Prioritization**
   - Identifying high-impact sectors
   - Policy development and evaluation
   - Resource allocation decisions

4. **Supply Chain Analysis**
   - Upstream impact assessment
   - Supplier environmental performance
   - Scope 3 emissions calculation

5. **Economic-Environmental Analysis**
   - Decoupling analysis
   - Green GDP calculations
   - Economic-environmental trade-offs

## Model Validation

### Validation Methods
1. **Reproduction of National Totals**
   - Model outputs validated against input data sources
   - Ensures data integrity through model construction

2. **Comparison with v1.2**
   - Analysis of changes from previous version
   - Changes explained by:
     - Data updates
     - Methodological improvements
     - Structural changes

## Data Availability

### Published Datasets
- Full model dataset
- Supporting datasets of national environmental totals by US industry
- Direct impact coefficients (D matrix)
- Total impact coefficients (N matrix)
- H_r and H_f matrices
- Build and validation scripts

### Access
- EPA Data Commons
- Figshare
- Zenodo
- Open source and reproducible

## Key Improvements from v1 Models

1. **More Current Data:** Environmental data updated to 2014-2017 where available
2. **Better Resolution:** 411 commodities vs. 385 in v1.0
3. **Enhanced Methodology:** Improved waste sector modeling, domestic/foreign separation
4. **Price Flexibility:** Multiple price variants and year adjustments
5. **Better Infrastructure:** Improved software tools and reproducibility

## Industry Classification

### NAICS Codes (Primary Classification System)
- **NAICS 2017** is the standard industry classification system used for environmental and employment data
- Hierarchical 6-digit structure (Sector → Subsector → Industry Group → Industry → U.S. Industry)
- Industry-based classification (what establishments do)
- See **NAICS_KNOWLEDGE_BASE.md** for comprehensive NAICS documentation

### BEA Commodity Categories
- USEEIO v2.0 model structure uses **411 BEA commodity categories** (based on 2012 BEA Detail IO tables)
- Product-based classification (what is produced)
- Crosswalks available to map between NAICS codes and BEA commodity categories

### Relationship
- Environmental data sources use **NAICS codes** to classify industries
- USEEIO model construction includes crosswalks to map NAICS-based data to **BEA commodity categories**
- The same USEEIO principles apply whether working with NAICS codes or BEA commodities

## Important Notes for Matching Applications

When building a matching agent for USEEIO v2.0 using NAICS codes:

1. **NAICS Code Matching:** 
   - Match at appropriate level (2-6 digits) based on precision needed
   - Use industry definitions and cross-references for accurate classification
   - Consider hierarchical relationships (broader codes encompass more specific ones)

2. **NAICS to BEA Mapping:** 
   - May need to map NAICS codes to BEA commodity categories for USEEIO model calculations
   - Crosswalks are available in USEEIO model construction tools
   - One NAICS code may map to multiple BEA commodities (and vice versa)

3. **Year Considerations:** 
   - Base year is 2012, but environmental data may be from different years (2014-2017)
   - NAICS definitions are versioned (2012, 2017, 2022) - ensure consistency

4. **Price Types:** 
   - Need to account for producer vs. purchaser price differences
   - Price adjustment matrices available in USEEIO

5. **Domestic vs. Foreign:** 
   - May need to separate domestic and imported impacts
   - Domestic model variant available in USEEIO

6. **Multiple Matrices:** 
   - Different matrices (D, N, H_r, H_f) serve different purposes
   - D = Direct impacts, N = Total impacts, H_r/H_f = Transformation matrices

## References

- **Primary Paper:** Ingwersen et al. (2022). USEEIO v2.0. *Scientific Data* 9:194
- **Software:** `useeior` R package (Zenodo: 10.5281/zenodo.6370101)
- **Data:** EPA Data Commons, Figshare repositories
- **Documentation:** USEEIO methodology papers and technical documentation

## Related Models

- **USEEIO v1.x Series:** Earlier versions with different structures
- **USEEIO v2.0 GHG Models:** Greenhouse gas-specific variants
- **International IO Models:** Similar models for other countries/regions

---

*This knowledge base is based on Ingwersen et al. (2022) and should be used as a reference for understanding USEEIO v2.0 structure, capabilities, and applications in the context of the USEEIOMatchingAgent project.*
