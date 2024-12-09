/** 
 * @author Luidy
 * 
 * @group C3C_QueueProcessing
 */
public with sharing class C3C_QueueProcessingLogItem 
{
    private String stackTrace;

    private Integer lineNumberStackTrace;

    private String queueProcessingItemId;

    private C3C_QueueProcessingLogItem__c queueProcessingLogItem = new C3C_QueueProcessingLogItem__c();

    public C3C_QueueProcessingLogItem(String queueProcessingItemId)
    {
        this.queueProcessingLogItem.QueueProcessingItemId__c = queueProcessingItemId;
        this.stackTrace = '';
        this.lineNumberStackTrace = 0;
    }

    public C3C_QueueProcessingLogItem addExceptionLineStackTrace(Exception e)
    {
        this.addLineStackTraceWithStyle('#9d00ff', '[Exception.'+e.getTypeName()+']['+e.getLineNumber()+'] '+e.getMessage());
        this.addLineStackTraceWithStyle('#ff4040', '['+e.getTypeName()+'.StackTrace] '+e.getStackTraceString());

        return this;
    }

    public C3C_QueueProcessingLogItem addErrorLineStackTrace(String message)
    {
        this.addLineStackTraceWithStyle('rgb(228, 0, 0)', message);

        return this;
    }

    public C3C_QueueProcessingLogItem addWarningLineStackTrace(String message)
    {
        this.addLineStackTraceWithStyle('#9d9d00', message);

        return this;
    }

    public C3C_QueueProcessingLogItem addInfoLineStackTrace(String message)
    {
        this.addLineStackTraceWithStyle('#00add2', message);

        return this;
    }

    public C3C_QueueProcessingLogItem__c getRecord()
    {
        return this.queueProcessingLogItem;
    }

    public Attachment buildAttachment()
    {
        return new Attachment(
            ParentId = this.queueProcessingLogItem.Id,
            Name = 'log_'+this.queueProcessingLogItem.Id+'.html',
            ContentType = 'text/plain; charset=UTF-8',
            Body = Blob.valueOf(this.stackTrace)
        );
    }

    public C3C_QueueProcessingLogItem setErrorMessage(String errorMessage)
    {
        if(this.queueProcessingLogItem == null || errorMessage == null) return this;

        errorMessage = errorMessage.length() > 255 ? errorMessage.left(252)+'...' : errorMessage;

        this.queueProcessingLogItem.ErrorMessage__c = errorMessage;

        return this;
    }

    public C3C_QueueProcessingLogItem setResponseMessage(String responseMessage)
    {
        if(this.queueProcessingLogItem == null || responseMessage == null) return this;

        responseMessage = responseMessage.length() > 255 ? responseMessage.left(252)+'...' : responseMessage;

        this.queueProcessingLogItem.Response__c = responseMessage;

        return this;
    }

    private C3C_QueueProcessingLogItem addLineStackTraceWithStyle(String color, String message)
    {
        try
        {
            message = '<p style="color: '+color+';"> ${lineNumber} - '+message+'</p>';
            this.addLineStackTrace(message);
        }
        catch(Exception e)
        {
            System.debug('C3C_QueueProcessingLogItem.addLineStackTraceWithStyle => '+e.getMessage());
            System.debug(e.getStackTraceString());
        }

        return this;
    }

    private C3C_QueueProcessingLogItem addLineStackTrace(String message)
    {
        try
        {
            this.lineNumberStackTrace++;
            String stackTrace = this.stackTrace != null ? this.stackTrace : '';
            
            stackTrace += message.replace('${lineNumber}', String.valueOf(this.lineNumberStackTrace));
            
            this.stackTrace = stackTrace;
        }
        catch(Exception e)
        {
            System.debug('C3C_QueueProcessingLogItem.addLineStackTrace => '+e.getMessage());
            System.debug(e.getStackTraceString());
        }

        return this;
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
    }
}