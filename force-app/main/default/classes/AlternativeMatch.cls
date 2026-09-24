/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

/**
 * @description Wrapper class for alternative matching options
 * @author Your Name
 * @date 2025-01-XX
 */
public class AlternativeMatch {
    @AuraEnabled public Id factorId { get; set; }
    @AuraEnabled public String naicsCode { get; set; }
    @AuraEnabled public String economicSector { get; set; }
    @AuraEnabled public Decimal emissionsFactorValue { get; set; }
    @AuraEnabled public Decimal confidenceScore { get; set; }
    @AuraEnabled public String reasoning { get; set; }
    
    /**
     * @description Default constructor
     */
    public AlternativeMatch() {
        this.confidenceScore = 0.0;
    }
    
    /**
     * @description Constructor with basic parameters
     * @param factorId The PcmtEmssnFctrSetItem record ID
     * @param naicsCode The NAICS code
     * @param economicSector The economic sector name
     */
    public AlternativeMatch(Id factorId, String naicsCode, String economicSector) {
        this();
        this.factorId = factorId;
        this.naicsCode = naicsCode;
        this.economicSector = economicSector;
    }
}
