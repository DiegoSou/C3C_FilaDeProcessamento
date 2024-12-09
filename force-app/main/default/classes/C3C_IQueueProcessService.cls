/** 
 * @author Diego
 * 
 * @group C3C_ProcessingQueue
 */
public interface C3C_IQueueProcessService 
{
    Object executeProcess(C3C_QueueProcessingItem__c queueProcessingItem);
}