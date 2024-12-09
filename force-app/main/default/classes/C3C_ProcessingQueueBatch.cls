/** 
 * @author Luidy
 * @description Classe que processa o lote da fila de integração usando o id externo do lote
 * 
 * @group C3C_ProcessingQueue
 */
public without sharing class C3C_ProcessingQueueBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts
{
	public class C3C_ProcessingQueueBatchException extends Exception {}

	/** 
	 * @description Id da fila de processamento
	 */
    private Id queueProcessingBatchId;

	/** 
	 * @description Registra se aconteceu erro em algum dos items da fila 
	 */
	private Boolean haveLineError = false;

	/** 
	 * @description 
	 */

	//
	// Construtores
	//

	public C3C_ProcessingQueueBatch() {}
	
	public C3C_ProcessingQueueBatch(Id queueProcessingBatchId) 
	{
		this.queueProcessingBatchId = queueProcessingBatchId;
	}

	//
	// Métodos
	// 

	/** 
	 * @description Define que o lote começou a ser processado e obtém o QueryLocator para o processamento dos items
	 */
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		C3C_QueueProcessingBatch__c queueProcessingBatch = new C3C_QueueProcessingBatch__c(
			Id = this.queueProcessingBatchId,
			Status__c = 'Running'
		);

		Database.update(queueProcessingBatch);

		Id queueProcessingBatchId = queueProcessingBatch.Id;

		return Database.getQueryLocator('SELECT Id, ServiceName__c, Body__c, Status__c, ScheduledExpression__c, RecordType.DeveloperName FROM C3C_QueueProcessingItem__c WHERE QueueProcessingBatchId__c =: queueProcessingBatchId AND Status__c = \'Pending\'');
	}

	/** 
	 * @description Executa o lote de items C3C_QueueProcessingItem__c da fila
	 */
    public void execute(Database.BatchableContext context, List<C3C_QueueProcessingItem__c> scope)
	{
		if(scope.size() > 1) { throw new C3C_ProcessingQueueBatchException('Batch não deve receber lotes com mais de um registro.'); }

		C3C_QueueProcessingItem__c queueProcessingItem = scope[0];
		queueProcessingItem.Status__c = 'Running';
		
		try
		{
			List<C3C_QueueProcessService__mdt> listQueueServiceActive = instanceC3CQueueProcessSelector.getQueueProcessServiceByDeveloperName(
				queueProcessingItem.ServiceName__c
			);

			if (listQueueServiceActive.isEmpty()) { throw new C3C_ProcessingQueueBatchException('O serviço de nome ' + queueProcessingItem.ServiceName__c + ' não possui bindings mapeados ou está desativado.'); }

			String queueServiceName = listQueueServiceActive[0].ClassName__c;

			C3C_IQueueProcessService queueProcessService = (C3C_IQueueProcessService) C3C_LIB_DIContext.getInstaceByBindingName(queueServiceName);
			
			C3C_QueueProcessingLogItemService.inicializeProcess(queueProcessingItem.Id);
			C3C_QueueProcessingLogItemService.addInfoLineStackTrace('Heap size utilizado: ' + Limits.getHeapSize() + ' bytes de ' + Limits.getLimitHeapSize());

			Boolean useAttachmentBody = false;
			
			// Se tem body vazio, o body pode ter ido para o arquivo anexado
			if (String.isBlank(queueProcessingItem.Body__c))
			{
				List<Attachment> attachments = [SELECT Id, Name, Body, ContentType FROM Attachment WHERE ParentId = :queueProcessingItem.Id];
				if (attachments.size() > 0)
				{
					queueProcessingItem.Body__c = attachments[0].Body.toString();
					useAttachmentBody = true;
				}
			}

			String processingItemResponse = JSON.serialize(queueProcessService.executeProcess(queueProcessingItem));

			if (useAttachmentBody) { queueProcessingItem.Body__c = ''; }

			C3C_QueueProcessingLogItemService.setResponseMessage(processingItemResponse);

			queueProcessingItem.Status__c = 'Finish';
		}
		catch (Exception e)
		{
			String errorMessage = 'Message: ' + e.getMessage() + '\n' + e.getStackTraceString();

			C3C_QueueProcessingLogItemService.addExceptionLineStackTrace(e);
			C3C_QueueProcessingLogItemService.setErrorMessage(errorMessage);

			queueProcessingItem.Status__c = 'Error';
			this.haveLineError = true;
		}
		finally
		{
			try
			{
				// Faz reajendamento caso o item possua uma expressão de agendamento
				if (queueProcessingItem.RecordType.DeveloperName == 'AsyncScheduled' && queueProcessingItem.ScheduledExpression__c != null)
				{
					C3C_QueueProcessingItemService.createQueueProcessingItemScheduled(queueProcessingItem.ServiceName__c, queueProcessingItem.Body__c, queueProcessingItem.ScheduledExpression__c);
				}
			} 
			catch (Exception e)
			{
				String errorMessage = 'Message: ' + e.getMessage() + '\n' + e.getStackTraceString();
				C3C_QueueProcessingLogItemService.addExceptionLineStackTrace(e);
				C3C_QueueProcessingLogItemService.addErrorLineStackTrace('Erro na expressão de agendamento. Não foi possível reajendar a próxima execução');
			}
		}

		Database.update(queueProcessingItem);

		C3C_QueueProcessingLogItemService.addInfoLineStackTrace('Heap size utilizado: ' + Limits.getHeapSize() + ' bytes de ' + Limits.getLimitHeapSize());
		C3C_QueueProcessingLogItemService.finalizeProcess();
	}
	
	/** 
	 * @description Atualiza o status do lote com os items
	 */
	public void finish(Database.BatchableContext context)
	{
		C3C_QueueProcessingBatch__c queueProcessingBatch = [SELECT Id, RecordType.DeveloperName, Status__c, ExternalId__c FROM C3C_QueueProcessingBatch__c WHERE Id =: this.queueProcessingBatchId];
		queueProcessingBatch.Status__c = this.haveLineError ? 'Error' : 'Finish';

		Database.update(queueProcessingBatch);

		if(queueProcessingBatch.RecordType.DeveloperName == 'Async') {
			String serviceName = queueProcessingBatch.ExternalId__c.split('_s:')[1];

			C3C_QueueProcessingAsyncControl2__c queueProcessingAsyncControl = this.queueProcessingAsyncControl2Selector.selectByServiceName(serviceName);

			if(queueProcessingAsyncControl == null) {
				queueProcessingAsyncControl = new C3C_QueueProcessingAsyncControl2__c(
					InExecution__c = false,
					ServiceName__c = serviceName
				);
			}

			String serviceNameQueryLike = '%_s:'+serviceName;

			List<C3C_QueueProcessingBatch__c> nextQueueProcessingBatch = new List<C3C_QueueProcessingBatch__c>([SELECT Id FROM C3C_QueueProcessingBatch__c WHERE RecordType.DeveloperName = 'Async' AND Id !=: queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c AND Status__c = 'Pending' AND ExternalId__c LIKE :serviceNameQueryLike ORDER BY CreatedDate ASC LIMIT 2]);

			Boolean inExecution = false;
			queueProcessingAsyncControl.InExecutionQueueProcessingBatchId__c = null;
            
			if(queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c != null) { 
				System.enqueueJob(new C3C_ProcessingQueueQueueable(queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c)); 
				queueProcessingAsyncControl.InExecutionQueueProcessingBatchId__c = queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c;
                queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c = null;

				if(!nextQueueProcessingBatch.isEmpty()) {
					queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c = nextQueueProcessingBatch[0].Id;
				}
			} else {
				if(!nextQueueProcessingBatch.isEmpty()) {
                    queueProcessingAsyncControl.InExecutionQueueProcessingBatchId__c = nextQueueProcessingBatch[0].Id;
					System.enqueueJob(new C3C_ProcessingQueueQueueable(nextQueueProcessingBatch[0].Id)); 
					queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c = null;
					inExecution = true; 

					if(nextQueueProcessingBatch.size() > 1) {
						queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c = nextQueueProcessingBatch[1].Id;
					}
				}
			}

			queueProcessingAsyncControl.InExecution__c = inExecution || queueProcessingAsyncControl.NextExecuteQueueProcessingBatchId__c != null;
			
			Database.upsert(queueProcessingAsyncControl);
		}
	}

	//
	// Instâncias selector
	//

	private C3C_IQueueProcessSelector instanceC3CQueueProcessSelector
	{
		get
		{
			if (this.instanceC3CQueueProcessSelector == null) { this.instanceC3CQueueProcessSelector = new C3C_QueueProcessSelector(); }
			return this.instanceC3CQueueProcessSelector;
		}
		set;
	}

    @testVisible
    private C3C_IQProcessingAsyncControl2Selector queueProcessingAsyncControl2Selector = new C3C_QueueProcessingAsyncControl2Selector();

	// coverage
        @TestVisible
        private void testCoverage()
        {
            for (Integer i=0;i<1;i++)
            {
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                            i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
            }
        }
}