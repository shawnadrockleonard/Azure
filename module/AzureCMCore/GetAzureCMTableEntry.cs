using AzureCMCore.Base;
using AzureCMCore.Models;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Management.Automation;

namespace AzureCMCore
{
    [Cmdlet("Get", "AzureCMTableEntry")]
    [CmdletHelp("Returns a row in the specified table with partition key", Category = "Base Cmdlets")]
    public class GetAzureCMTableEntry : AzureCmdlet
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



        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            var storageCreds = new StorageCredentials(StorageAccountName, StorageKey);
            var storageAccount = new CloudStorageAccount(storageCreds, EndPointSuffix, true);

            try
            {
                CloudTableClient tableClient = storageAccount.CreateCloudTableClient();
                CloudTable drTable = tableClient.GetTableReference(TableName);


                var getOrSelect = TableOperation.Retrieve<TemplateTableLogModel>(PartitionKey, PartitionKey);

                var tableResult = drTable.ExecuteAsync(getOrSelect).GetAwaiter().GetResult();
                WriteObject(tableResult);
            }
            catch (Exception ex)
            {
                Error(ex, ErrorCategory.InvalidData, Properties.Resources.StorageTableReadFailure, TableName, PartitionKey);
            }
        }
    }
}
