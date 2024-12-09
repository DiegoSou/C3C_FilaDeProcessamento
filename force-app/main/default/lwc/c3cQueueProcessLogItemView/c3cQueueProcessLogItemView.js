import { LightningElement, api, wire, track } from 'lwc';
import getAttachmentsContent from '@salesforce/apex/C3C_QueueProcessLogItemViewController.getAttachmentsContent';

export default class C3cQueueProcessLogItemView extends LightningElement 
{
    @api recordId;
    @track richtext;

    @wire(getAttachmentsContent, { parentRecordId: '$recordId' })
    attachments({ error, data}) {
        this.richtext = data;
    }
}