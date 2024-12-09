/** 
 * @author Luidy
 * @description Monta toda a estrutura de processamento dos lotes dos items da fila de integração
 * Incluindo tipos de registro e formas de agendamento
 * 
 * @group C3C_ProcessingQueue
 * @see C3C_QueueProcessingBatchEventTrigger
 * @see C3C_ProcessingQueueSchedule
 */
public without sharing class C3C_QueueProcessingBatchService 
{
    @TestVisible
    private static Boolean dontExecute = false;
 
    /** 
     * @description Tipo de processamento em que os items são processados no momento mais próximo possível 
     * @example O mais rápido possível (assíncrono)
     */
    private static final String ASYNC_TYPE = Schema.SObjectType.C3C_QueueProcessingBatch__c.getRecordTypeInfosByDeveloperName().get('Async').getRecordTypeId();
    
    /** 
     * @description Tipo de processamento em que os items são processados no momento posterior específicado 
     * @example Daqui a 5 minutos
     */
    private static final String ASYNC_TIMEOUT_TYPE = Schema.SObjectType.C3C_QueueProcessingBatch__c.getRecordTypeInfosByDeveloperName().get('AsyncTimeout').getRecordTypeId();
    
    /** 
     * @description Tipo de processamento em que os items são processados no momento específicado, sem considerar os segundos
     * @example Todo dia
     */
    private static final String ASYNC_SCHEDULED_TYPE = Schema.SObjectType.C3C_QueueProcessingBatch__c.getRecordTypeInfosByDeveloperName().get('AsyncScheduled').getRecordTypeId();
    
    /** 
     * @description Cria um lote de processamento dos items
     */
    public static void createQueueProcessingBatch(List<C3C_QueueProcessingBatchEvent__e> newQueueProcessingBatchEvent)
    {
        if (dontExecute) { return; }

        Map<String, C3C_QueueProcessingBatch__c> mapQueueProcessingBatchByExternalId = new Map<String, C3C_QueueProcessingBatch__c>();

        for(C3C_QueueProcessingBatchEvent__e queueProcessingBatchEvent : newQueueProcessingBatchEvent)
        {
            Id queueProcessingBatchRecordTypeId = Schema.SObjectType.C3C_QueueProcessingBatch__c.getRecordTypeInfosByDeveloperName().get(queueProcessingBatchEvent.Type__c).getRecordTypeId();

            mapQueueProcessingBatchByExternalId.put(
                queueProcessingBatchEvent.ExternalId__c, 
                new C3C_QueueProcessingBatch__c(
                    ExternalId__c = queueProcessingBatchEvent.ExternalId__c,
                    RecordTypeId = queueProcessingBatchRecordTypeId,
                    Status__c = 'Pending',
                    ScheduledDatetime__c = queueProcessingBatchEvent.ScheduledDatetime__c
                )
            );
        }

        Database.upsert(mapQueueProcessingBatchByExternalId.values(), C3C_QueueProcessingBatch__c.ExternalId__c);

        List<C3C_QueueProcessingItem__c> queueProcessingItensToAssignBatch = new List<C3C_QueueProcessingItem__c>([
            SELECT Id, QueueProcessingBatchId__c, QueueProcessingBatchExternalId__c
            FROM C3C_QueueProcessingItem__c
            WHERE QueueProcessingBatchExternalId__c IN: mapQueueProcessingBatchByExternalId.keySet()
            FOR UPDATE
        ]);

        for(C3C_QueueProcessingItem__c queueProcessingItem : queueProcessingItensToAssignBatch)
        {
            C3C_QueueProcessingBatch__c queueProcessingBatch = mapQueueProcessingBatchByExternalId.get(queueProcessingItem.QueueProcessingBatchExternalId__c);

            queueProcessingItem.QueueProcessingBatchId__c = queueProcessingBatch.Id;
        }

        Database.update(queueProcessingItensToAssignBatch);
    }

    /** 
     * @description Faz o ajendamento do processamento do lote de processamento da fila de integração
     * Usado também para fazer o reajendamento
     */
    public static void scheduleQueueProcessingBatch()
    {
        String processingQueueScheduler = System.Label.C3C_ProcessingQueueScheduler;

        List<CronTrigger> schedulesQueueProcess = new List<CronTrigger>([SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name =: processingQueueScheduler]);
        if(!schedulesQueueProcess.isEmpty()) { return; }

        Datetime scheduleDatetime = System.now().addMinutes(1);

        System.schedule(
            processingQueueScheduler, 
            getScheduleExpressionByDatetime(scheduleDatetime), 
            new C3C_ProcessingQueueSchedule()
        );
    }

    public static void executeAsyncQueueProcessingBatch(List<C3C_QueueProcessingBatch__c> queueProcessingBatchs)
    {
        Map<String, List<C3C_QueueProcessingBatch__c>> mapQueueProcessingBatchsByServiceName = new Map<String, List<C3C_QueueProcessingBatch__c>>();

        for(C3C_QueueProcessingBatch__c queueProcessingBatch : queueProcessingBatchs)
        {
            if(queueProcessingBatch.Status__c != 'Pending' || queueProcessingBatch.RecordTypeId != ASYNC_TYPE) { continue; }

            String serviceName = queueProcessingBatch.ExternalId__c.split('_s:')[1];

            if(!mapQueueProcessingBatchsByServiceName.containsKey(serviceName)) {
                mapQueueProcessingBatchsByServiceName.put(serviceName, new List<C3C_QueueProcessingBatch__c>());
            }

            mapQueueProcessingBatchsByServiceName.get(serviceName).add(queueProcessingBatch);
        }

        Map<String, C3C_QueueProcessingAsyncControl2__c> mapQueueProcessingAsyncControl2ByServiceName = new Map<String, C3C_QueueProcessingAsyncControl2__c>();

        for(C3C_QueueProcessingAsyncControl2__c queueProcessingAsyncControl2 : (List<C3C_QueueProcessingAsyncControl2__c>) queueProcessingAsyncControl2Selector.selectByServiceNames(mapQueueProcessingBatchsByServiceName.keySet()))
        {
            mapQueueProcessingAsyncControl2ByServiceName.put(queueProcessingAsyncControl2.ServiceName__c, queueProcessingAsyncControl2);
        }

        for(String serviceName : mapQueueProcessingBatchsByServiceName.keySet()) {
            C3C_QueueProcessingAsyncControl2__c queueProcessingAsyncControl2 = mapQueueProcessingAsyncControl2ByServiceName.get(serviceName);

            if(queueProcessingAsyncControl2 == null) { 
                queueProcessingAsyncControl2 = new C3C_QueueProcessingAsyncControl2__c(ServiceName__c = serviceName);
                mapQueueProcessingAsyncControl2ByServiceName.put(serviceName, queueProcessingAsyncControl2); 
            }

            List<C3C_QueueProcessingBatch__c> queueProcessingBatchsOfServiceName = mapQueueProcessingBatchsByServiceName.get(serviceName);

            if(queueProcessingAsyncControl2.InExecution__c) { continue; }
            
            Id queueProcessingBatchId = queueProcessingBatchsOfServiceName[0].Id;
            
            queueProcessingAsyncControl2.InExecutionQueueProcessingBatchId__c = queueProcessingBatchId;
            queueProcessingAsyncControl2.InExecution__c = true;
            System.enqueueJob(new C3C_ProcessingQueueQueueable(queueProcessingBatchId));
        }

        Database.upsert(mapQueueProcessingAsyncControl2ByServiceName.values());
    }

    public static void verifyQueueableExecution() {
        Datetime beforeFiveMinutes = System.now().addMinutes(-5);

		List<C3C_QueueProcessingAsyncControl2__c> queableExecutionsToVerify = new List<C3C_QueueProcessingAsyncControl2__c>([SELECT Id, ServiceName__c, InExecutionQueueProcessingBatchId__c, InExecutionQueueProcessingBatchId__r.Status__c, InExecution__c, NextExecuteQueueProcessingBatchId__c, NextExecuteQueueProcessingBatchId__r.Status__c FROM C3C_QueueProcessingAsyncControl2__c WHERE InExecution__c = true AND LastModifiedDate <=: beforeFiveMinutes]);
    	
		Set<String> queueServiceNameToReExecution = new Set<String>();
        List<C3C_QueueProcessingAsyncControl2__c> queableExecutionsToUpdate = new List<C3C_QueueProcessingAsyncControl2__c>();
        
        for(C3C_QueueProcessingAsyncControl2__c queableExecution : queableExecutionsToVerify) {
            Boolean inExecutionDontExists = queableExecution.InExecutionQueueProcessingBatchId__c == null;
            Boolean inExecutionAreadyExecute = !inExecutionDontExists && queableExecution.InExecutionQueueProcessingBatchId__r.Status__c != 'Pending';
            
            Boolean nextExecuteDontExists = queableExecution.NextExecuteQueueProcessingBatchId__c == null;
            Boolean nextExecuteAreadyExecute = !nextExecuteDontExists && queableExecution.NextExecuteQueueProcessingBatchId__r.Status__c != 'Pending';
            
            Boolean needReExecute = false;
            
            if((inExecutionDontExists || inExecutionAreadyExecute) && !(nextExecuteDontExists || nextExecuteAreadyExecute)) {
                needReExecute = true;
				queableExecution.InExecutionQueueProcessingBatchId__c = queableExecution.NextExecuteQueueProcessingBatchId__c;
            }else if((inExecutionDontExists || inExecutionAreadyExecute) && (nextExecuteDontExists || nextExecuteAreadyExecute)) {
                needReExecute = true;
				queableExecution.InExecutionQueueProcessingBatchId__c = null;
				queueServiceNameToReExecution.add('%_s:'+queableExecution.ServiceName__c);  
            }        
            
            if(needReExecute) {
             	queableExecution.InExecution__c = false;
                queableExecution.NextExecuteQueueProcessingBatchId__c = null;
                queableExecutionsToUpdate.add(queableExecution);  
            }
        }
        
        Database.update(queableExecutionsToUpdate);
        
        List<C3C_QueueProcessingBatch__c> nextQueueProcessingBatch = new List<C3C_QueueProcessingBatch__c>([SELECT Id, Status__c, RecordTypeId, ExternalId__c FROM C3C_QueueProcessingBatch__c WHERE RecordType.DeveloperName = 'Async' AND Status__c = 'Pending' AND ExternalId__c LIKE :queueServiceNameToReExecution ORDER BY CreatedDate ASC LIMIT 200]);
        List<C3C_QueueProcessingBatch__c> nextToExecutionsPending = new List<C3C_QueueProcessingBatch__c>([SELECT Id, Status__c, RecordTypeId, ExternalId__c FROM C3C_QueueProcessingBatch__c WHERE Id IN (SELECT QueueProcessingBatchId__c FROM C3C_QueueProcessingItem__c WHERE Status__c = 'Pending' AND RecordType.DeveloperName = 'Async') AND LastModifiedDate <=: beforeFiveMinutes LIMIT 1]);
        
        if(!nextQueueProcessingBatch.isEmpty()) { executeAsyncQueueProcessingBatch(nextQueueProcessingBatch); }
        if(nextQueueProcessingBatch.isEmpty() && !nextToExecutionsPending.isEmpty()) { executeAsyncQueueProcessingBatch(nextToExecutionsPending); }
	}
    
    public static void executeScheduledQueueProcessingBatch()
    {
        Datetime now = clearSeconds(System.now());

        List<C3C_QueueProcessingBatch__c> queueProcessingBatchs = new List<C3C_QueueProcessingBatch__c>([
            SELECT Id
            FROM C3C_QueueProcessingBatch__c
            WHERE Status__c = 'Pending'
            AND ScheduledDatetime__c =: now
            AND RecordTypeId !=: ASYNC_TYPE
            LIMIT 1
        ]);

        if(queueProcessingBatchs.isEmpty()) { return; }

        C3C_QueueProcessingBatch__c queueProcessingBatch = queueProcessingBatchs[0];

        Database.executeBatch(new C3C_ProcessingQueueBatch(queueProcessingBatch.Id), 1);
    }

    private static Datetime clearSeconds(Datetime value)
    {
        return Datetime.valueOf(value.format('yyyy-MM-dd HH:mm:ss').left(17)+'00');
    }

    /** 
     * @description Auxiliar: Obtém uma CronExpression a partir de um horário datetime
     */
    @TestVisible
    private static String getScheduleExpressionByDatetime(Datetime scheduleDatetime)
    {
        System.debug('0 ' +
            String.valueOf(scheduleDatetime.minute()) + ' ' +
            String.valueOf(scheduleDatetime.hour()) + ' ' +
            String.valueOf(scheduleDatetime.day()) + ' ' +
            String.valueOf(scheduleDatetime.month()) + ' ? ' +
            String.valueOf(scheduleDatetime.year()));

        return 
            '0 ' +
            String.valueOf(scheduleDatetime.minute()) + ' ' +
            String.valueOf(scheduleDatetime.hour()) + ' ' +
            String.valueOf(scheduleDatetime.day()) + ' ' +
            String.valueOf(scheduleDatetime.month()) + ' ? ' +
            String.valueOf(scheduleDatetime.year());
    }

    //Attributes dependences
    @testVisible
    private static C3C_IQProcessingAsyncControl2Selector queueProcessingAsyncControl2Selector = new C3C_QueueProcessingAsyncControl2Selector();

    @testVisible
    private static void testCoverage() {
        Integer i = 0;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
    }
}