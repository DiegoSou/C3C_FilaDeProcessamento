/** 
 * @author Diego
 * 
 * @description Controller para o componente lwc "c3cQueueProcessLogItemView"
 */
public without sharing class C3C_QueueProcessLogItemViewController 
{
    /** 
     * @description Obtém os anexos associados com o log de item da fila de processamento
     */
    @AuraEnabled(cacheable=true)
    public static String getAttachmentsContent(String parentRecordId)
    {
        List<Attachment> attachments = [SELECT Id, Body, ContentType, ParentId FROM Attachment WHERE ParentId =: parentRecordId];

        String contentString = '';

        for (Attachment attch : attachments) { contentString += attch.Body.toString() + '<br><br>'; }

        return contentString;
    }
}