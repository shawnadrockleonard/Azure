namespace AzQueueProcessor.Function
{
    using Azure.Storage.Blobs;
    using AzQueueProcessor.Common.Extensions;
    using AzQueueProcessor.Common.Models;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;
    using Microsoft.Extensions.Configuration;
    using System;

    public class QueueProcessor
    {
        private readonly IManagedIdentityExtensions msidentity;
        private readonly IConfiguration config;

        public QueueProcessor(IManagedIdentityExtensions identity, IConfiguration configuration)
        {
            msidentity = identity;
            config = configuration;
        }

        [FunctionName("QueueProcessor")]
        public void Run([ServiceBusTrigger(queueName: "%hubqueuename%", Connection = "hub1SERVICEBUS")] string smsg, ILogger log,
            [Table("%tabledblogname%", Connection = "tabledblog")] out TableLogItem tableentry)
        {
            var fileInfo = Newtonsoft.Json.JsonConvert.DeserializeObject<ExpectedFileInfo>(smsg);
            var sourceSasUri = fileInfo.SasUri;
            log.LogInformation($"ServiceBus queue trigger function processed message: {sourceSasUri}");

            // Get Configs
            var processorVersion = config["version"];
            var destBlobAccount = config["datapipelinesend"];
            var destsendcontainer = config["datapipelinesendcontainer"];
            var destsendsb = config["servicebussend"];
            var destsendsbtopicname = config["servicebustopicname"];

            // 
            UriBuilder sasUri = new UriBuilder(sourceSasUri);
            var sourceClient = new BlobClient(sasUri.Uri);

            // Placeholder for moving to dynamic connection
            // TODO: commented until we move to MSI  var msi = msidentity.GetAzureCredentials();

            // Placeholder for parsing XML into JSON
            // TODO: commented until we parse into JSON -- sourceClient.GetDeserializedBlobAsync(log).GetAwaiter().GetResult();

            // Upload File
            var destClient = new BlobServiceClient(destBlobAccount);
            var destContainer = destClient.GetBlobContainerClient(destsendcontainer);
            var destBlobClient = sourceClient.CopyBlobAsync(destContainer, fileInfo, log).GetAwaiter().GetResult();
            if (destBlobClient == null)
            {
                log.LogError($"Failed to retreive file {sourceClient.Name} from source storage.");
                tableentry = (new TableLogItem()
                {
                    PartitionKey = "consumer",
                    RowKey = Guid.NewGuid().ToString(),
                    Operation = "QueueProcessorFailed",
                    Message = $"Failed to retreive file {sourceClient.Name} from source storage.",
                    FileName = fileInfo.FileName,
                    EventTimestamp = DateTime.Now,
                    CustomerID = fileInfo.CustomerID,
                    Tags = fileInfo.Tags,
                    CorrelationId = fileInfo.CorrelationId,
                    ProcessorVersion = processorVersion
                });
                return;
            }

            // Write Queue Now
            destBlobClient.WriteMessageAsync(destsendcontainer, destsendsb, destsendsbtopicname, fileInfo, log).GetAwaiter().GetResult();


            // Write Log to Azure storage table
            tableentry = (new TableLogItem()
            {
                PartitionKey = "consumer",
                RowKey = Guid.NewGuid().ToString(),
                Operation = "QueueProcessor",
                Message = $"ServiceBus queue trigger function processed message: {sourceSasUri}",
                FileName = fileInfo.FileName,
                EventTimestamp = DateTime.Now,
                CustomerID = fileInfo.CustomerID,
                Tags = fileInfo.Tags,
                CorrelationId = fileInfo.CorrelationId,
                ProcessorVersion = processorVersion
            });
        }
    }
}
