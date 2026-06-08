/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Wrapper class for matching results from USEEIO matching service
 * @author Your Name
 * @date 2025-01-XX
 */
public class MatchingResult {
    /**
     * @description The Scope3PcmtItem record ID that was matched
     */
    public Id scope3PcmtItemId { get; set; }
    
    /**
     * @description The recommended PcmtEmssnFctrSetItem record ID
     */
    public Id recommendedFactorId { get; set; }
    
    /**
     * @description The recommended NAICS code (6-digit)
     */
    public String recommendedNaicsCode { get; set; }
    
    /**
     * @description The recommended economic sector name
     */
    public String recommendedEconomicSector { get; set; }
    
    /**
     * @description The emissions factor value (tCO2e per million USD)
     */
    public Decimal emissionsFactorValue { get; set; }
    
    /**
     * @description Confidence score (0.0 - 1.0)
     */
    public Decimal confidenceScore { get; set; }
    
    /**
     * @description LLM reasoning/explanation for the match
     */
    public String reasoning { get; set; }
    
    /**
     * @description Alternative matches that were considered
     */
    public List<AlternativeMatch> alternatives { get; set; }
    
    /**
     * @description Status of the match: MATCHED, NO_MATCH, REQUIRES_REVIEW
     */
    public String status { get; set; }
    
    /**
     * @description Error message if match failed
     */
    public String errorMessage { get; set; }
    
    /**
     * @description Default constructor
     */
    public MatchingResult() {
        this.alternatives = new List<AlternativeMatch>();
        this.status = 'NO_MATCH';
        this.confidenceScore = 0.0;
    }
    
    /**
     * @description Constructor with basic parameters
     * @param scope3PcmtItemId The Scope3PcmtItem record ID
     * @param status The match status
     */
    public MatchingResult(Id scope3PcmtItemId, String status) {
        this();
        this.scope3PcmtItemId = scope3PcmtItemId;
        this.status = status;
    }
}
