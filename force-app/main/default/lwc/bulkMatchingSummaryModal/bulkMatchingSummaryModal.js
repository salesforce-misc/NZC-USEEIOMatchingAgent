/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

import LightningModal from 'lightning/modal';
import { api } from 'lwc';

export default class BulkMatchingSummaryModal extends LightningModal {
    @api recordId;
    
    handleClose() {
        this.close();
    }
}
