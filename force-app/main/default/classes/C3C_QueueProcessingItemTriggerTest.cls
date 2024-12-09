@isTest
public with sharing class C3C_QueueProcessingItemTriggerTest {
    @isTest
    public static void insertTriggerTest()
    {
        try
        {
            C3C_QueueProcessingItemService.dontExecute = true;
            insert new C3C_QueueProcessingItem__c();
        }catch(Exception ex) {}
    }
}