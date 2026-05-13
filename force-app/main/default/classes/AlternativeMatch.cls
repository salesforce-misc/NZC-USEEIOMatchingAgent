/**
 * @description Wrapper class for alternative matching options
 * @author Your Name
 * @date 2025-01-XX
 */
public class AlternativeMatch {
    /**
     * @description The PcmtEmssnFctrSetItem record ID
     */
    public Id factorId { get; set; }
    
    /**
     * @description The NAICS code (6-digit)
     */
    public String naicsCode { get; set; }
    
    /**
     * @description The economic sector name
     */
    public String economicSector { get; set; }
    
    /**
     * @description The emissions factor value (tCO2e per million USD)
     */
    public Decimal emissionsFactorValue { get; set; }
    
    /**
     * @description Confidence score for this alternative (0.0 - 1.0)
     */
    public Decimal confidenceScore { get; set; }
    
    /**
     * @description Reasoning for why this alternative was considered
     */
    public String reasoning { get; set; }
    
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
