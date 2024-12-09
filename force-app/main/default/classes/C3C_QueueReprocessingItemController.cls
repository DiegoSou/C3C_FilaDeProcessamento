/** 
 * @author Diego
 * @date 27/08/2024
 * 
 * @description Reprocessar itens da fila de integração
 */
@SuppressWarnings('PMD')
public virtual class C3C_QueueReprocessingItemController 
{
    /** 
     * @description Tipo de processamento em que os items são processados no momento mais próximo possível 
     */
    private static final String ASYNC_TYPE = Schema.SObjectType.C3C_QueueProcessingItem__c.getRecordTypeInfosByDeveloperName().get('Async').getRecordTypeId();

    @AuraEnabled
    public static Boolean reprocessQueueItems(List<String> queueProcessingItemIds)
    {
        try 
        {
            List<C3C_QueueProcessingItem__c> itemsToReprocess = new List<C3C_QueueProcessingItem__c>();
            
            String query = (
                'SELECT '+
                    'Id,'+
                    'ServiceName__c,'+
                    'Body__c '+
                'FROM C3C_QueueProcessingItem__c '+
                'WHERE Id IN :queueProcessingItemIds '
            );

            for (C3C_QueueProcessingItem__c item : (List<C3C_QueueProcessingItem__c>) Database.query(query))
            {
                itemsToReprocess.add(new C3C_QueueProcessingItem__c(
                    ServiceName__c = item.ServiceName__c,
                    Body__c = item.Body__c,
                    RecordTypeId = ASYNC_TYPE
                ));
            }

            if (!Test.isRunningTest()) { Database.insert(itemsToReprocess); }
            return true;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
}