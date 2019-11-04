using AzureCMCore.Base;
using AzureCMCore.Models;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Management.Automation;

namespace AzureCMCore
{
    [Cmdlet("Write", "AzureCMTableEntry")]
    [CmdletHelp("Returns a token which can be used for further authentication", Category = "Base Cmdlets")]
    public class WriteAzureCMTableEntry : AzureCmdlet
    {
        [Parameter(Mandatory = true, HelpMessage = "The storage account DNS resolver name.")]
        public string StorageAccountName { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The storage base64 encoded key.")]
        public string StorageKey { get; set; }

        [Parameter(Mandatory = false, HelpMessage = "The endpoint suffix for which Azure environment to which we are writing.")]
        public string EndPointSuffix { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The table name where rows will be stored.")]
        public string TableName { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The row unique identifier.")]
        public string PartitionKey { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The storage base64 encoded key.")]
        public string RowContents { get; set; }


        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            try
            {
                var storageCreds = new StorageCredentials(StorageAccountName, StorageKey);
                var storageAccount = new CloudStorageAccount(storageCreds, EndPointSuffix, true);

                CloudTableClient tableClient = storageAccount.CreateCloudTableClient();
                CloudTable drTable = tableClient.GetTableReference(TableName);
                var result = drTable.CreateIfNotExistsAsync().GetAwaiter().GetResult();

                var templateEntity = new TemplateTableLogModel(PartitionKey)
                {
                    LogContent = RowContents
                };

                TableOperation insertOrReplace = TableOperation.InsertOrReplace(templateEntity);

                var tableResult = drTable.ExecuteAsync(insertOrReplace).GetAwaiter().GetResult();
                WriteObject(tableResult);
            }
            catch (Exception ex)
            {
                Error(ex, ErrorCategory.InvalidOperation, Properties.Resources.TableWriteFailure, TableName);
            }
        }
    }
}
