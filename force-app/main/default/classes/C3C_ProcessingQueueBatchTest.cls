@isTest
public with sharing class C3C_ProcessingQueueBatchTest {
    private static C3C_ProcessingQueueBatch processingQueueBatch = new C3C_ProcessingQueueBatch();

    @isTest
    static void coverage()
    {
        processingQueueBatch.testCoverage();
    }
}