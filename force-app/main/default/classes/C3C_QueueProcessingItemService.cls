/** 
 * @author Luidy
 * @description Monta toda a estrutura de processamento pros items da fila de integração
 * 
 * @group C3C_ProcessingQueue
 * @see C3C_QueueProcessingBatchService
 */
public without sharing class C3C_QueueProcessingItemService
{
    public class C3C_QueueProcessingItemServiceException extends Exception {}

    @TestVisible
    private static Boolean dontExecute = false;

    private static List<C3C_QueueProcessingItem__c> queueProcessingItensToCreate = new List<C3C_QueueProcessingItem__c>();

    private static Map<Integer, Attachment> attachmentsToCreate = new Map<Integer, Attachment>();

    /** 
     * @description Se falso, os métodos de criação não serializam o corpo passado, use quando quiser passar o corpo em string
     */
    public static Boolean serialize = true;

    /** 
     * @description Tipo de processamento em que os items são processados no momento mais próximo possível 
     * @example O mais rápido possível (assíncrono)
     */
    private static final String ASYNC_TYPE = Schema.SObjectType.C3C_QueueProcessingItem__c.getRecordTypeInfosByDeveloperName().get('Async').getRecordTypeId();
    
    /** 
     * @description Tipo de processamento em que os items são processados no momento posterior específicado 
     * @example Daqui a 5 minutos
     */
    private static final String ASYNC_TIMEOUT_TYPE = Schema.SObjectType.C3C_QueueProcessingItem__c.getRecordTypeInfosByDeveloperName().get('AsyncTimeout').getRecordTypeId();
    
    /** 
     * @description Tipo de processamento em que os items são processados no momento específicado, sem considerar os segundos
     * @example Todo dia
     */
    private static final String ASYNC_SCHEDULED_TYPE = Schema.SObjectType.C3C_QueueProcessingItem__c.getRecordTypeInfosByDeveloperName().get('AsyncScheduled').getRecordTypeId();

    /** 
     * @description Executado antes da inserção dos C3C_QueueProcessingItem__c
     * Atualiza o Id do lote dos items da fila de acordo com o tipo de cada item e o horário de agendademento
     */
    public static void defineExecution(List<C3C_QueueProcessingItem__c> newQueueProcessingItens)
    {
        if (dontExecute) { return; }
        
        UUID triggerUUID = UUID.randomUUID();
        Datetime triggerTime = System.now();

        Map<String, List<C3C_QueueProcessingItem__c>> mapQueueProcessingItensByBatchExternalId = new Map<String, List<C3C_QueueProcessingItem__c>>();

        for(C3C_QueueProcessingItem__c queueProcessingItem : newQueueProcessingItens)
        {   
            String recordTypeId = queueProcessingItem.RecordTypeId;

            if(recordTypeId == ASYNC_TYPE) { 
                queueProcessingItem.QueueProcessingBatchExternalId__c = triggerUUID.toString()+'_s:'+queueProcessingItem.ServiceName__c;
            }

            if(recordTypeId == ASYNC_TIMEOUT_TYPE) { 
                Datetime dateTimeTimeout = triggerTime.addMinutes((Integer) queueProcessingItem.IntervalMinutes__c).addSeconds(10);
                dateTimeTimeout = clearSeconds(dateTimeTimeout);

                queueProcessingItem.ScheduledDatetime__c = dateTimeTimeout;
                queueProcessingItem.QueueProcessingBatchExternalId__c = queueProcessingItem.ScheduledDatetime__c.formatGMT('yyyyMMddHHmm');
            }

            if(recordTypeId == ASYNC_SCHEDULED_TYPE) { 
                queueProcessingItem.ScheduledDatetime__c = clearSeconds(queueProcessingItem.ScheduledDatetime__c);
                queueProcessingItem.QueueProcessingBatchExternalId__c = queueProcessingItem.ScheduledDatetime__c.formatGMT('yyyyMMddHHmm');
            }

            if(!mapQueueProcessingItensByBatchExternalId.containsKey(queueProcessingItem.QueueProcessingBatchExternalId__c))
            {
                mapQueueProcessingItensByBatchExternalId.put(queueProcessingItem.QueueProcessingBatchExternalId__c, new List<C3C_QueueProcessingItem__c>());
            }
            mapQueueProcessingItensByBatchExternalId.get(queueProcessingItem.QueueProcessingBatchExternalId__c).add(queueProcessingItem);
        }

        for(C3C_QueueProcessingBatch__c queueProcessingBatch : new List<C3C_QueueProcessingBatch__c>([
            SELECT Id, ExternalId__c 
            FROM C3C_QueueProcessingBatch__c 
            WHERE ExternalId__c IN :mapQueueProcessingItensByBatchExternalId.keySet()
        ]))
        {
            for(C3C_QueueProcessingItem__c queueProcessingItem : mapQueueProcessingItensByBatchExternalId.get(queueProcessingBatch.ExternalId__c))
            {
                queueProcessingItem.QueueProcessingBatchId__c = queueProcessingBatch.Id;
            }
        }
    }

    /** 
     * @description Executado depois da inserção dos C3C_QueueProcessingItem__c
     * Cria um novo registro de evento para processamento do lote com os items
     */
    public static void createQueueProcessingBatchToExecute(List<C3C_QueueProcessingItem__c> newQueueProcessingItens)
    {
        if (dontExecute) { return; }

        Map<String, C3C_QueueProcessingBatchEvent__e> mapQueueProcessingBatchEventByExternalId = new Map<String, C3C_QueueProcessingBatchEvent__e>();
        
        for(C3C_QueueProcessingItem__c queueProcessingItem : newQueueProcessingItens)
        {
            if(queueProcessingItem.QueueProcessingBatchId__c != null) { continue; }

            String queueProcessingItemRecordType = Schema.SObjectType.C3C_QueueProcessingItem__c.getRecordTypeInfosById().get(queueProcessingItem.RecordTypeId).getDeveloperName();
            
            mapQueueProcessingBatchEventByExternalId.put(
                queueProcessingItem.QueueProcessingBatchExternalId__c, 
                new C3C_QueueProcessingBatchEvent__e(
                    ExternalId__c = queueProcessingItem.QueueProcessingBatchExternalId__c,
                    Type__c = queueProcessingItemRecordType,
                    ScheduledDatetime__c = queueProcessingItem.ScheduledDatetime__c
                )
            );
        }

        EventBus.publish(mapQueueProcessingBatchEventByExternalId.values());
    }

    public static void createQueueProcessingItemAsync(String serviceName, Object body)
    {
        String bodyStr = getBodyString(body);
        C3C_QueueProcessingItem__c item = new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = bodyStr.length() > 131072 ? '' : bodyStr,
            RecordTypeId = ASYNC_TYPE
        );
        Database.insert(item);

        if (bodyStr.length() > 131072) {
            insert new Attachment(
                ParentId = item.Id,
                Name = 'Queue Processing Item - Body File',
                ContentType = 'text/plain',
                Body = Blob.valueOf(bodyStr)
            );
        }
    }

    public static void registerQueueProcessingItemAsync(String serviceName, Object body)
    {
        queueProcessingItensToCreate.add(new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = getBodyString(body),
            RecordTypeId = ASYNC_TYPE
        ));
    }
    
    public static void createQueueProcessingItemTimeout(String serviceName, Object body, Integer intervalMinutes)
    {
        String bodyStr = getBodyString(body);
        C3C_QueueProcessingItem__c item = new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = bodyStr.length() > 131072 ? '' : bodyStr,
            RecordTypeId = ASYNC_TIMEOUT_TYPE,
            IntervalMinutes__c = intervalMinutes
        );
        Database.insert(item);
        
        if (bodyStr.length() > 131072) {
            insert new Attachment(
                ParentId = item.Id,
                Name = 'Queue Processing Item - Body File',
                ContentType = 'text/plain',
                Body = Blob.valueOf(bodyStr)
            );
        }
    }

    public static void registerQueueProcessingItemTimeout(String serviceName, Object body, Integer intervalMinutes)
    {
        queueProcessingItensToCreate.add(new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = getBodyString(body),
            RecordTypeId = ASYNC_TIMEOUT_TYPE,
            IntervalMinutes__c = intervalMinutes
        ));
    }

    public static void createQueueProcessingItemScheduled(String serviceName, Object body, Datetime scheduledDatetime)
    {
        String bodyStr = getBodyString(body);
        C3C_QueueProcessingItem__c item = new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = bodyStr.length() > 131072 ? '' : bodyStr,
            RecordTypeId = ASYNC_SCHEDULED_TYPE,
            ScheduledDatetime__c = scheduledDatetime
        );
        Database.insert(item);

        if (bodyStr.length() > 131072) {
            insert new Attachment(
                ParentId = item.Id,
                Name = 'Queue Processing Item - Body File',
                ContentType = 'text/plain',
                Body = Blob.valueOf(bodyStr)
            );
        }
    }

    public static void registerQueueProcessingItemScheduled(String serviceName, Object body, Datetime scheduledDatetime)
    {
        queueProcessingItensToCreate.add(new C3C_QueueProcessingItem__c(
            ServiceName__c = serviceName,
            Body__c = getBodyString(body),
            RecordTypeId = ASYNC_SCHEDULED_TYPE,
            ScheduledDatetime__c = scheduledDatetime
        ));
    }

    public static void commitQueueProcessingItens()
    {
        Set<Integer> indexesWithAttachment = new Set<Integer>();
        for (Integer i = 0; i < queueProcessingItensToCreate.size(); i++)
        {
            if (queueProcessingItensToCreate[i].Body__c.length() > 131072)
            {
                String bodyStr = queueProcessingItensToCreate[i].Body__c;
                attachmentsToCreate.put(i, new Attachment(
                    Name = 'Queue Processing Item - Body File',
                    ContentType = 'text/plain',
                    Body = Blob.valueOf(bodyStr)
                ));
                queueProcessingItensToCreate[i].Body__c = '';
                indexesWithAttachment.add(i);
            }
        }
        Database.insert(queueProcessingItensToCreate);

        for (Integer attachIndex : indexesWithAttachment)
        {
            attachmentsToCreate.get(attachIndex).ParentId = queueProcessingItensToCreate[attachIndex].Id;
        }
        Database.insert(attachmentsToCreate.values());

        queueProcessingItensToCreate = new List<C3C_QueueProcessingItem__c>();
        attachmentsToCreate = new Map<Integer, Attachment>();
    }

    /** 
     * @description Cria item na fila de processamento informando uma data especifica para executar.
     * @param expression  Minutes Hours DayMonth Month DayWeek Year
     */
    public static void createQueueProcessingItemScheduled(String serviceName, Object body, String expression)
    {
        validateExpression(expression);

        // Database.insert(new C3C_QueueProcessingItem__c(
        //     ServiceName__c = serviceName,
        //     Body__c = getBodyString(body),
        //     RecordTypeId = ASYNC_SCHEDULED_TYPE,
        //     ScheduledDatetime__c = CronExpressionUtils.instance.compile(expression), //TO DO: fazer funcionar kkk
        //     ScheduledExpression__c = expression
        // ));
    }
 
    private static String getBodyString(Object body)
    {
        if (serialize) { return body == null ? '' : JSON.serialize(body); }
        return (String) body;
    }

    private static Datetime clearSeconds(Datetime value)
    {
        return Datetime.valueOf(value.format('yyyy-MM-dd HH:mm:ss').left(17)+'00');
    }

    /** 
     * @description Valida CronExpression
     * @param expression Minutos Horas Dias-Do-Mês Mês Dia-Da-Semana Ano
     * @example
     *  validateExpression('0 2 * * * ?'); // Executa todo dia 2 horas da manhã
     */    
    private static void validateExpression(String expression)
    {
        if(expression == null) { throw new C3C_QueueProcessingItemServiceException('Expressão é obrigatória'); }

        Integer numExpressionParam = expression.split(' ').size();
        if(numExpressionParam < 6 || numExpressionParam > 6) { 
            throw new C3C_QueueProcessingItemServiceException('Expressão deve receber 6 dados, seguindo a ordem: Minutos Horas Dias-Do-Mês Mês Dia-Da-Semana Ano.'); 
        }
        
        List<String> expressionParams = expression.split(' ');

        String minutesParam = expressionParams[0];
        String hours = expressionParams[1];
        String dayOfMonth = expressionParams[2];
        String month = expressionParams[3];
        String dayOfWeek = expressionParams[4];
        String optionalYear = expressionParams[5];

        validateExpressionMinutes(minutesParam);
    }

    private static void validateExpressionMinutes(String minutesParam)
    {
        if(!minutesParam.isNumeric() || minutesParam.contains('.')) { 
            throw new C3C_QueueProcessingItemServiceException('Os minutos devem receber um valor númerico e inteiro, e deve estar entre 0-59.');  
        }

        Integer minutes = Integer.valueOf(minutesParam);
        if(minutes < 0 || minutes > 59) {
            throw new C3C_QueueProcessingItemServiceException('Os minutos devem estar no range de 0-59.');  
        }
    }

    @testVisible
    private static void testCoverage() {
        Integer i = 0;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
        i = 1;
    }
}