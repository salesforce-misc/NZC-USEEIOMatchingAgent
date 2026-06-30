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
    @AuraEnabled public Id scope3PcmtItemId { get; set; }
    @AuraEnabled public Id recommendedFactorId { get; set; }
    @AuraEnabled public String recommendedNaicsCode { get; set; }
    @AuraEnabled public String recommendedEconomicSector { get; set; }
    @AuraEnabled public Decimal emissionsFactorValue { get; set; }
    @AuraEnabled public Decimal confidenceScore { get; set; }
    @AuraEnabled public String reasoning { get; set; }
    @AuraEnabled public List<AlternativeMatch> alternatives { get; set; }
    @AuraEnabled public String status { get; set; }
    @AuraEnabled public String errorMessage { get; set; }
    
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
