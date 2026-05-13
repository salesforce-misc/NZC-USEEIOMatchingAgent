import LightningModal from 'lightning/modal';
import { api } from 'lwc';

export default class BulkMatchingSummaryModal extends LightningModal {
    @api recordId;
    
    handleClose() {
        this.close();
    }
}
