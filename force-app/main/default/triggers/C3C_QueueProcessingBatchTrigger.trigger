/** 
 * @author Luidy
 * 
 * @group C3C_ProcessingQueue
 */
trigger C3C_QueueProcessingBatchTrigger on C3C_QueueProcessingBatch__c (before insert, after insert) 
{
    if(Trigger.isInsert)
    {
        if(Trigger.isAfter)
        {
            C3C_QueueProcessingBatchService.executeAsyncQueueProcessingBatch(Trigger.new);
            C3C_QueueProcessingBatchService.scheduleQueueProcessingBatch();
        }
    }
}