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
    [Cmdlet("Get", "AzureCMTableConnection")]
    [CmdletHelp("Returns a connection string for a storage account", Category = "Base Cmdlets")]
    public class GetAzureCMTableConnection : AzureCmdlet
    {
        [Parameter(Mandatory = true, HelpMessage = "The storage account DNS resolver name.")]
        public string StorageAccountName { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The storage base64 encoded key.")]
        public string StorageKey { get; set; }

        [Parameter(Mandatory = false, HelpMessage = "The Azure environment.")]
        [ValidateSet(new string[] { "Azure", "AzureUSGovernment" }, IgnoreCase = true)]
        public string Environment { get; set; }

        /// <summary>
        /// Creates a SDK connection and returns the primary and secondary URI's
        /// </summary>
        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();

            var EndPointSuffix = "core.windows.net";
            if (Environment.Equals("AzureUSGovernment", StringComparison.InvariantCultureIgnoreCase))
            {
                EndPointSuffix = "core.usgovcloudapi.net";
            }

            var storageCreds = new StorageCredentials(StorageAccountName, StorageKey);
            var storageAccount = new CloudStorageAccount(storageCreds, EndPointSuffix, true);

            try
            {
                var primaryString = string.Format("BlobEndpoint={0};QueueEndpoint={1};TableEndpoint={2};AccountName={3};AccountKey={4}", 
                    storageAccount.BlobStorageUri.PrimaryUri,
                    storageAccount.QueueStorageUri.PrimaryUri,
                    storageAccount.TableStorageUri.PrimaryUri, 
                    StorageAccountName, StorageKey);

                var secondaryString = string.Format("BlobEndpoint={0};QueueEndpoint={1};TableEndpoint={2};AccountName={3};AccountKey={4}",
                    storageAccount.BlobStorageUri.SecondaryUri,
                    storageAccount.QueueStorageUri.SecondaryUri,
                    storageAccount.TableStorageUri.SecondaryUri, 
                    StorageAccountName, StorageKey);

                var connect = new
                {
                    PrimaryUri = primaryString,
                    SecondaryUri = secondaryString
                };

                WriteObject(connect);
            }
            catch (Exception ex)
            {
                LogError(ex, ErrorCategory.InvalidData, "Failed to get storage {0} connection", StorageAccountName);
            }
        }
    }
}
