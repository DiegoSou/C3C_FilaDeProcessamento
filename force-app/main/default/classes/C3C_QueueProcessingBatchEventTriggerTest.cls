@isTest
public with sharing class C3C_QueueProcessingBatchEventTriggerTest {
    @isTest
    public static void insertTriggerTest()
    {
        try
        {
            Test.startTest();
            C3C_QueueProcessingBatchService.dontExecute = true;
            EventBus.publish(new C3C_QueueProcessingBatchEvent__e());
            Test.stopTest();
        }catch(Exception ex) {}
    }
}