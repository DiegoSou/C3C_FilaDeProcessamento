/** 
 * @author Luidy
 * @description Representa o processamento dos lotes de item da fila de integração 
 * Classe Queueable para executar cada lote de item.
 * 
 * @group C3C_ProcessingQueue
 * @see C3C_ProcessingQueueBatch
 */
public without sharing class C3C_ProcessingQueueQueueable implements Queueable 
{
    /** 
     * @description Id do lote de processamento da fila
     */
    private Id queueProcessingBatchId;

    //
    // Construtores
    //

    public C3C_ProcessingQueueQueueable() {}

    public C3C_ProcessingQueueQueueable(Id queueProcessingBatchId)
    {
        this.queueProcessingBatchId = queueProcessingBatchId;
    }

    //
    // Métodos
    //

    /** 
     * @description Roda batch para iniciar o processamento do lote
     */
    public void execute(System.QueueableContext context)
    {
        if(!Test.isRunningTest()) { Database.executeBatch(new C3C_ProcessingQueueBatch(this.queueProcessingBatchId), 1); }
    }
}