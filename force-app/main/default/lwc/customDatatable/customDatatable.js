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
