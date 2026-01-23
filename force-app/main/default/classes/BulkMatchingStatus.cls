/**
 * @description Wrapper class for bulk matching status (for LWC polling)
 * @author Your Name
 * @date 2025-01-XX
 */
public class BulkMatchingStatus {
    @AuraEnabled
    public String status { get; set; } // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETE', 'ERROR'
    
    @AuraEnabled
    public Integer totalItems { get; set; }
    
    @AuraEnabled
    public Integer processedItems { get; set; }
    
    @AuraEnabled
    public Integer matchedItems { get; set; }
    
    @AuraEnabled
    public Integer needsReviewItems { get; set; }
    
    @AuraEnabled
    public String jobId { get; set; }
    
    @AuraEnabled
    public DateTime completedDate { get; set; }
    
    @AuraEnabled
    public String errorMessage { get; set; }
    
    @AuraEnabled
    public Decimal progressPercentage { get; set; }
    
    /**
     * @description Default constructor
     */
    public BulkMatchingStatus() {
        this.status = 'NOT_STARTED';
        this.totalItems = 0;
        this.processedItems = 0;
        this.matchedItems = 0;
        this.needsReviewItems = 0;
        this.progressPercentage = 0.0;
    }
    
    /**
     * @description Calculate progress percentage
     */
    public void calculateProgress() {
        if (this.totalItems > 0) {
            this.progressPercentage = (Decimal.valueOf(this.processedItems) / Decimal.valueOf(this.totalItems)) * 100.0;
        } else {
            this.progressPercentage = 0.0;
        }
    }
}
