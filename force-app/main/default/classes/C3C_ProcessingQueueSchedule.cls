/** 
 * @author Luidy
 * @description Schedulable agendada para processamento dos lotes de fila de integração
 * 
 * @group C3C_ProcessingQueue
 * @see C3C_QueueProcessingBatchService
 */
global without sharing class C3C_ProcessingQueueSchedule implements Schedulable 
{
    global void execute(SchedulableContext sc) 
    {
        C3C_QueueProcessingBatchService.executeScheduledQueueProcessingBatch();
        try { C3C_QueueProcessingBatchService.verifyQueueableExecution(); } catch(Exception except) { System.debug(except); }

        if(sc != null) 
        { 
            System.abortJob(sc.getTriggerId()); 
        }
        
        // Reajendamento
        C3C_QueueProcessingBatchService.scheduleQueueProcessingBatch();
    }
}