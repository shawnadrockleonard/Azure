using AzureCM.Module.Base;
using AzureCM.Module.Models;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
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



        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();

            try
            {
                var storageCreds = new StorageCredentials(StorageAccountName, StorageKey);
                var storageAccount = new CloudStorageAccount(storageCreds, EndPointSuffix, true);

                CloudTableClient tableClient = storageAccount.CreateCloudTableClient();
                CloudTable drTable = tableClient.GetTableReference(TableName);
                var result = drTable.CreateIfNotExists();

                var templateEntity = new TemplateTableLogModel(PartitionKey);
                templateEntity.LogContent = RowContents;

                TableOperation insertOrReplace = TableOperation.InsertOrReplace(templateEntity);

                var tableResult = drTable.Execute(insertOrReplace);
                WriteObject(tableResult);
            }
            catch (Exception ex)
            {
                LogError(ex, ErrorCategory.InvalidOperation, "Failed to write to table {0}", TableName);
            }
        }
    }
}
