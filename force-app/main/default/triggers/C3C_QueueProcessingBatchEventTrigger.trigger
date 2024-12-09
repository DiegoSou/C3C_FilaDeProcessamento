/** 
 * @author Luidy
 * 
 * @group C3C_ProcessingQueue
 */
trigger C3C_QueueProcessingBatchEventTrigger on C3C_QueueProcessingBatchEvent__e (after insert) 
{
    if(Trigger.isInsert && Trigger.isAfter) { C3C_QueueProcessingBatchService.createQueueProcessingBatch(Trigger.new); }
}