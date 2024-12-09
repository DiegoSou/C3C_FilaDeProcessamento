/** 
 * @author Luidy
 * 
 * @group C3C_ProcessingQueue
 */
trigger C3C_QueueProcessingItemTrigger on C3C_QueueProcessingItem__c (before insert, after insert) 
{
    if(Trigger.isInsert) 
    {
        if(Trigger.isBefore)
        {
            C3C_QueueProcessingItemService.defineExecution(Trigger.new);
        }

        if(Trigger.isAfter) 
        {
            C3C_QueueProcessingItemService.createQueueProcessingBatchToExecute(Trigger.new);
        }
    }
}