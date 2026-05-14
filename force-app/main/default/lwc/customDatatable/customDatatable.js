/*
 * Copyright (c) 2026, Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */

import LightningDatatable from 'lightning/datatable';
import lookupCellTemplate from './lookupCellTemplate.html';

export default class CustomDatatable extends LightningDatatable {
    static customTypes = {
        lookup: {
            template: lookupCellTemplate,
            standardCellLayout: true,
            typeAttributes: ['value', 'factorSetId', 'itemId', 'displayName']
        }
    };
}
