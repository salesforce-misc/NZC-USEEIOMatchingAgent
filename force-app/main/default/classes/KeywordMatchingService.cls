/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Service for keyword-based pre-filtering of NAICS codes
 * @description Reduces 1016 NAICS codes to top 30-50 candidates before LLM analysis
 * @author Your Name
 * @date 2025-01-XX
 */
public class KeywordMatchingService {
    
    /**
     * @description Common stop words to filter out during keyword extraction
     */
    private static final Set<String> STOP_WORDS = new Set<String>{
        'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'for', 'on', 'with', 
        'at', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be', 'been', 
        'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 
        'should', 'could', 'may', 'might', 'must', 'can', 'this', 'that', 
        'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'what', 
        'which', 'who', 'whom', 'whose', 'where', 'when', 'why', 'how', 'all', 
        'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some', 'such', 
        'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very'
    };
    
    /**
     * @description Industry-specific keywords that should have higher weight
     */
    private static final Map<String, Integer> INDUSTRY_KEYWORD_WEIGHTS = new Map<String, Integer>{
        'manufacturing' => 20,
        'production' => 15,
        'services' => 15,
        'consulting' => 15,
        'retail' => 15,
        'wholesale' => 15,
        'construction' => 15,
        'transportation' => 15,
        'warehousing' => 15,
        'utilities' => 15,
        'mining' => 15,
        'agriculture' => 15,
        'fishing' => 15,
        'forestry' => 15
    };
    
    /**
     * @description Find candidate NAICS codes based on keyword matching
     * @description Scores all 1016 PcmtEmssnFctrSetItem records and returns top N candidates
     * @param category1 First spending category
     * @param category2 Second spending category
     * @param category3 Third spending category
     * @param topN Number of top candidates to return (default 50)
     * @return List of candidate NAICS codes (6-digit strings)
     */
    public static List<String> findCandidateNaicsCodes(
        String category1, 
        String category2, 
        String category3,
        Integer topN
    ) {
        if (topN == null || topN <= 0) {
            topN = 50;
        }
        
        // Extract keywords from spending categories
        Set<String> keywords = extractKeywords(category1, category2, category3);
        
        if (keywords.isEmpty()) {
            return new List<String>();
        }
        
        // Query all PcmtEmssnFctrSetItem records
        List<PcmtEmssnFctrSetItem> allFactors = [
            SELECT EconomicSectorCode, EconomicSector, EconomicSectorCategory
            FROM PcmtEmssnFctrSetItem
            WHERE EconomicSectorCode != null
            ORDER BY EconomicSectorCode
        ];
        
        // Score each NAICS code
        Map<String, Integer> naicsScores = new Map<String, Integer>();
        for (PcmtEmssnFctrSetItem factor : allFactors) {
            if (factor.EconomicSectorCode != null) {
                Integer score = calculateScore(keywords, factor);
                if (score > 0) {
                    // If code already exists, take the higher score
                    if (!naicsScores.containsKey(factor.EconomicSectorCode) || 
                        naicsScores.get(factor.EconomicSectorCode) < score) {
                        naicsScores.put(factor.EconomicSectorCode, score);
                    }
                }
            }
        }
        
        // Sort by score and return top N
        return getTopCandidates(naicsScores, topN);
    }
    
    /**
     * @description Extract keywords from spending categories
     * @param cat1 First category
     * @param cat2 Second category
     * @param cat3 Third category
     * @return Set of extracted keywords
     */
    private static Set<String> extractKeywords(String cat1, String cat2, String cat3) {
        Set<String> keywords = new Set<String>();
        
        // Combine all categories
        String combined = '';
        if (String.isNotBlank(cat1)) {
            combined += ' ' + cat1;
        }
        if (String.isNotBlank(cat2)) {
            combined += ' ' + cat2;
        }
        if (String.isNotBlank(cat3)) {
            combined += ' ' + cat3;
        }
        
        if (String.isBlank(combined)) {
            return keywords;
        }
        
        // Normalize: lowercase, remove punctuation
        combined = combined.toLowerCase();
        combined = combined.replaceAll('[^a-z0-9\\s]', ' ');
        
        // Tokenize
        List<String> tokens = combined.split('\\s+');
        
        // Filter out stop words and short tokens
        for (String token : tokens) {
            token = token.trim();
            if (token.length() > 2 && !STOP_WORDS.contains(token)) {
                keywords.add(token);
            }
        }
        
        return keywords;
    }
    
    /**
     * @description Calculate match score for a factor based on keywords
     * @param keywords Set of keywords to match
     * @param factor PcmtEmssnFctrSetItem record
     * @return Score (higher = better match)
     */
    private static Integer calculateScore(Set<String> keywords, PcmtEmssnFctrSetItem factor) {
        Integer score = 0;
        
        String sector = (factor.EconomicSector != null ? factor.EconomicSector.toLowerCase() : '');
        String category = (factor.EconomicSectorCategory != null ? factor.EconomicSectorCategory.toLowerCase() : '');
        String combined = sector + ' ' + category;
        
        for (String keyword : keywords) {
            // Check for exact matches in sector (highest weight)
            if (sector.contains(keyword)) {
                Integer weight = INDUSTRY_KEYWORD_WEIGHTS.containsKey(keyword) 
                    ? INDUSTRY_KEYWORD_WEIGHTS.get(keyword) 
                    : 10;
                score += weight;
            }
            
            // Check for exact matches in category
            if (category.contains(keyword)) {
                score += 8;
            }
            
            // Check for partial matches
            if (combined.contains(keyword)) {
                score += 5;
            }
        }
        
        return score;
    }
    
    /**
     * @description Get top N candidates sorted by score
     * @param naicsScores Map of NAICS code to score
     * @param topN Number of top candidates to return
     * @return List of NAICS codes (sorted by score, descending)
     */
    private static List<String> getTopCandidates(Map<String, Integer> naicsScores, Integer topN) {
        // Convert to list of wrapper objects for sorting
        List<NaicsScore> scoreList = new List<NaicsScore>();
        for (String code : naicsScores.keySet()) {
            scoreList.add(new NaicsScore(code, naicsScores.get(code)));
        }
        
        // Sort by score (descending)
        scoreList.sort();
        
        // Return top N codes
        List<String> candidates = new List<String>();
        Integer count = Math.min(topN, scoreList.size());
        for (Integer i = 0; i < count; i++) {
            candidates.add(scoreList[i].code);
        }
        
        return candidates;
    }
    
    /**
     * @description Inner class for sorting NAICS codes by score
     */
    private class NaicsScore implements Comparable {
        public String code;
        public Integer score;
        
        public NaicsScore(String code, Integer score) {
            this.code = code;
            this.score = score;
        }
        
        public Integer compareTo(Object obj) {
            NaicsScore other = (NaicsScore)obj;
            // Sort descending (highest score first)
            if (this.score > other.score) {
                return -1;
            } else if (this.score < other.score) {
                return 1;
            }
            return 0;
        }
    }
}
