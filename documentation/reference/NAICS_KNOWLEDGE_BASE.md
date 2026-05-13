# NAICS 2017 Knowledge Base
## North American Industry Classification System

## Overview

**NAICS** (North American Industry Classification System) is the standard used by Federal statistical agencies in classifying business establishments for the purpose of collecting, analyzing, and publishing statistical data related to the U.S. business economy.

**Reference:** NAICS Codes 2017 Definition File - U.S. Census Bureau

## NAICS Structure

NAICS uses a hierarchical 6-digit coding system:

### Hierarchy Levels

1. **Sector (2-digit)** - The highest level of classification
   - Example: `11` = Agriculture, Forestry, Fishing and Hunting
   - Example: `92` = Public Administration

2. **Subsector (3-digit)** - Groups of related industries
   - Example: `111` = Crop Production
   - Example: `926` = Administration of Economic Programs

3. **Industry Group (4-digit)** - More specific groupings
   - Example: `1111` = Oilseed and Grain Farming
   - Example: `9261` = Administration of Economic Programs

4. **Industry (5-digit)** - Specific industry categories
   - Example: `11111` = Soybean Farming
   - Example: `92611` = Administration of General Economic Programs

5. **U.S. Industry (6-digit)** - Most detailed level, U.S.-specific
   - Example: `111110` = Soybean Farming
   - Example: `926110` = Administration of General Economic Programs

## Key NAICS Sectors (2017)

### Sector 11 - Agriculture, Forestry, Fishing and Hunting
- **111** - Crop Production
  - 1111 - Oilseed and Grain Farming
    - 111110 - Soybean Farming
    - 111120 - Oilseed (except Soybean) Farming
    - 111130 - Dry Pea and Bean Farming
    - 111140 - Wheat Farming
    - 111150 - Corn Farming
    - 111160 - Rice Farming
    - 11119 - Other Grain Farming
      - 111191 - Oilseed and Grain Combination Farming
      - 111199 - All Other Grain Farming
  - 1112 - Vegetable and Melon Farming
  - 1113 - Fruit and Tree Nut Farming
  - 1114 - Greenhouse, Nursery, and Floriculture Production
  - 1119 - Other Crop Farming
- **112** - Animal Production and Aquaculture
- **113** - Forestry and Logging
- **114** - Fishing, Hunting and Trapping
- **115** - Support Activities for Agriculture and Forestry

### Sector 92 - Public Administration
- **921** - Executive, Legislative, and Other General Government Support
- **922** - Justice, Public Order, and Safety Activities
- **923** - Administration of Human Resource Programs
- **924** - Administration of Environmental Quality Programs
- **925** - Administration of Housing Programs, Urban Planning, and Community Development
  - 92511 - Administration of Housing Programs
    - 925110 - Administration of Housing Programs
  - 92512 - Administration of Urban Planning and Community and Rural Development
    - 925120 - Administration of Urban Planning and Community and Rural Development
- **926** - Administration of Economic Programs
  - 92611 - Administration of General Economic Programs
    - 926110 - Administration of General Economic Programs
  - 92612 - Regulation and Administration of Transportation Programs
    - 926120 - Regulation and Administration of Transportation Programs
  - 92613 - Regulation and Administration of Communications, Electric, Gas, and Other Utilities
    - 926130 - Regulation and Administration of Communications, Electric, Gas, and Other Utilities
  - 92614 - Regulation of Agricultural Marketing and Commodities
    - 926140 - Regulation of Agricultural Marketing and Commodities
  - 92615 - Regulation, Licensing, and Inspection of Miscellaneous Commercial Sectors
    - 926150 - Regulation, Licensing, and Inspection of Miscellaneous Commercial Sectors
- **927** - Space Research and Technology
  - 92711 - Space Research and Technology
    - 927110 - Space Research and Technology
- **928** - National Security and International Affairs
  - 92811 - National Security
    - 928110 - National Security
  - 92812 - International Affairs
    - 928120 - International Affairs

## NAICS Classification Principles

### Primary Activity Rule
- Establishments are classified based on their **primary activity** (the activity that generates the most revenue)
- When an establishment has multiple activities, the primary one determines classification

### Industry Definitions
- Each industry has a detailed definition describing what activities are included
- **Cross-References** are provided to guide classification when activities might overlap

### Combination Classifications
- Some industries accommodate establishments with mixed activities
- Example: `111191` - Oilseed and Grain Combination Farming (when no single crop accounts for ≥50% of production)

### Exclusions
- Each industry definition includes explicit exclusions
- Cross-references guide classification of excluded activities to appropriate industries

## NAICS and USEEIO v2.0

### Relationship to USEEIO
- **USEEIO v2.0 uses BEA commodity categories** (411 commodities based on 2012 BEA Detail IO tables)
- **NAICS codes are used for industry classification** in environmental and employment data
- **Crosswalks exist** to map between NAICS codes and BEA commodity categories
- The same USEEIO principles apply whether using NAICS or BEA commodities:
  - Environmental impact calculation
  - Resource use tracking
  - Waste generation
  - Economic flow analysis
  - Employment metrics

### Data Mapping
- Environmental data sources use NAICS codes to classify industries
- USEEIO model construction includes crosswalks to map NAICS-based environmental data to BEA commodity categories
- For matching applications, you may work directly with NAICS codes or need to map to BEA commodities

## NAICS Code Structure Examples

### Complete 6-Digit Code Breakdown
```
111110 - Soybean Farming
││││││
│││││└─ U.S. Industry (6th digit)
││││└── Industry (5th digit)
│││└──── Industry Group (4th digit)
││└────── Subsector (3rd digit)
│└──────── Sector (2nd digit)
```

### Sector Coverage
NAICS 2017 covers all economic activities in the United States:
- **Sectors 11-23:** Goods-producing sectors (Agriculture, Mining, Construction, Manufacturing, Utilities)
- **Sectors 31-33:** Manufacturing (detailed)
- **Sectors 42-81:** Service-providing sectors (Wholesale, Retail, Transportation, Information, Finance, Real Estate, Professional Services, etc.)
- **Sector 92:** Public Administration

## Important Notes for Matching Applications

When building a matching agent using NAICS codes:

1. **Hierarchical Matching:** 
   - Can match at any level (2-digit through 6-digit)
   - More specific codes (6-digit) provide better precision
   - Less specific codes (2-3 digit) provide broader coverage

2. **Code Format:**
   - Always 6 digits for complete codes
   - Leading zeros are significant (e.g., `011110` not `11110`)
   - Can truncate to less specific levels when needed

3. **Cross-References:**
   - Use industry definitions and cross-references to handle edge cases
   - Some activities may map to multiple potential codes
   - Primary activity determines classification

4. **USEEIO Integration:**
   - May need to map NAICS codes to BEA commodity categories
   - Environmental data typically provided by NAICS code
   - USEEIO model uses crosswalks for this mapping

5. **Year Considerations:**
   - NAICS codes are updated periodically (2012, 2017, 2022)
   - USEEIO v2.0 uses 2012 base year, but may reference 2017 NAICS
   - Ensure version consistency when matching

6. **Industry Descriptions:**
   - Each code has detailed description of included activities
   - Use descriptions for semantic matching
   - Cross-references help resolve ambiguous cases

## NAICS vs. Other Classification Systems

### NAICS vs. SIC (Standard Industrial Classification)
- NAICS replaced SIC in 1997
- NAICS is more detailed and reflects modern economy
- Some historical data may still use SIC codes

### NAICS vs. BEA Commodity Categories
- **NAICS:** Industry-based classification (what establishments do)
- **BEA Commodities:** Product-based classification (what is produced)
- One industry can produce multiple commodities
- One commodity can be produced by multiple industries
- Crosswalks required for mapping

## Data Sources

- **Official NAICS Definitions:** U.S. Census Bureau
- **NAICS Search:** https://www.census.gov/naics/
- **NAICS Association:** Commercial provider of NAICS data and tools
- **BLS (Bureau of Labor Statistics):** Uses NAICS for employment data
- **EPA:** Uses NAICS for environmental data

## References

- NAICS Codes 2017 Definition File - U.S. Census Bureau
- North American Industry Classification System: https://www.census.gov/naics/
- Ingwersen et al. (2022). USEEIO v2.0. *Scientific Data* 9:194

---

*This knowledge base provides the foundation for understanding NAICS codes and their application in USEEIO-based environmental-economic analysis. The same USEEIO principles apply whether working with NAICS codes or BEA commodity categories.*
