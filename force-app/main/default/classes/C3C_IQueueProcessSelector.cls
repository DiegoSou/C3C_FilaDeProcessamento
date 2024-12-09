/** 
 * @author Diego
 * 
 * @group C3C_ProcessingQueue
 */
public interface C3C_IQueueProcessSelector 
{
    List<C3C_QueueProcessService__mdt> getQueueProcessServiceByDeveloperName(String developerName);
}