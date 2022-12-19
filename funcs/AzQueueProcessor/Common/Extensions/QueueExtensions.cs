using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using AzQueueProcessor.Common.Models;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Threading.Tasks;

namespace AzQueueProcessor.Common.Extensions
{
    public static class QueueExtensions
    {
        public static async Task WriteMessageAsync(this BlobClient destinationBlob, string destinationContainerName, string connectionString, string topicName, JPOFileInfo info, ILogger log)
        {
            var destinationSasUri = destinationBlob.GetServiceSASUriForBlob(destinationContainerName, null, log);

            // create a Service Bus client 
            await using ServiceBusClient client = new ServiceBusClient(connectionString);

            // create a sender for the topic
            ServiceBusSender sender = client.CreateSender(topicName);

            var payload = new JPOTopicInfo
            {
                FileName = info.FileName,
                SasUri = destinationSasUri.ToString(),
                CorrelationId = info.CorrelationId,
                CustomerID = info.CustomerID,
                Description = info.Description,
                MessageDate = DateTime.UtcNow,
                Origin = info.Origin
            };

            await sender.SendMessageAsync(new ServiceBusMessage(JsonConvert.SerializeObject(payload)));
            log.LogInformation($"Sent payload {payload.SasUri} to the topic: {topicName}");
        }
    }
}
