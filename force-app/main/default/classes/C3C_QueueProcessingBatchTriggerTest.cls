@isTest
public with sharing class C3C_QueueProcessingBatchTriggerTest {
    @isTest
    public static void insertTriggerTest() {
        try {
            insert new C3C_QueueProcessingBatch__c();
        } catch (Exception ex) {}
    }
}