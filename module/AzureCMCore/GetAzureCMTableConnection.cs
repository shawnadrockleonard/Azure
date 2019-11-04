using AzureCMCore.Base;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation;
using System.Text;

namespace AzureCMCore
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
        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            var EndPointSuffix = "core.windows.net";
            if (Environment.Equals("AzureUSGovernment", StringComparison.InvariantCultureIgnoreCase))
            {
                EndPointSuffix = "core.usgovcloudapi.net";
            }

            var storageCreds = new StorageCredentials(StorageAccountName, StorageKey);
            var storageAccount = new CloudStorageAccount(storageCreds, EndPointSuffix, true);

            try
            {
                var primaryString = string.Format(CultureInfo.CurrentCulture, "BlobEndpoint={0};QueueEndpoint={1};TableEndpoint={2};AccountName={3};AccountKey={4}",
                    storageAccount.BlobStorageUri.PrimaryUri,
                    storageAccount.QueueStorageUri.PrimaryUri,
                    storageAccount.TableStorageUri.PrimaryUri,
                    StorageAccountName, StorageKey);

                var secondaryString = string.Format(CultureInfo.CurrentCulture, "BlobEndpoint={0};QueueEndpoint={1};TableEndpoint={2};AccountName={3};AccountKey={4}",
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
                Error(ex, ErrorCategory.InvalidData, Properties.Resources.StorageConnectionFailure, StorageAccountName);
            }
        }
    }
}

