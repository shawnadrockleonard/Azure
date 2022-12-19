using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using AzQueueProcessor.Common.Models;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace AzQueueProcessor.Common.Extensions
{
    public static class BlobExtensions
    {
        public static async Task<Catalog> GetDeserializedBlobAsync(this BlobClient sourceClient, ILogger log)
        {
            Catalog serializedData = null;
            XmlSerializer serializer = new XmlSerializer(typeof(Catalog));

            try
            {
                // validate
                await sourceClient.GetPropertiesAsync();

                // get contents
                var fileContents = await sourceClient.DownloadAsync();
                var xmlData = fileContents.GetRawResponse();
                var checkXml = string.Empty;

                using var streamReader = new StreamReader(fileContents.Value.Content);
                checkXml = streamReader.ReadToEnd();

                using var sr = new StringReader(checkXml);
                serializedData = (Catalog)serializer.Deserialize(sr);

                log.LogInformation($"Found book count## {serializedData?.Books?.Count}");
            }
            catch (Exception ex)
            {
                log.LogError($"Failed to download {sourceClient.Uri} with response. {ex.Message}");
            }

            return serializedData;
        }

        public static async Task<BlobClient> CopyBlobAsync(this BlobClient sourceBlob, BlobContainerClient destContainer, JPOFileInfo info, ILogger log)
        {
            try
            {
                // Get the name of the first blob in the container to use as the source.
                string blobName = info.FileName;

                // Ensure that the source blob exists.
                if (await sourceBlob.ExistsAsync())
                {
                    // Get the source blob's properties
                    var sourceProperties = await sourceBlob.GetPropertiesAsync();
                    log.LogInformation($"Source file length: {sourceProperties.Value.ContentLength}", info);

                    Uri blob_sas_uri = sourceBlob.Uri;

                    // Get a BlobClient representing the destination blob
                    BlobClient destBlob = destContainer.GetBlobClient(blobName);

                    // Start the copy operation.
                    await destBlob.StartCopyFromUriAsync(blob_sas_uri);

                    // Get the destination blob's properties and display the copy status.
                    var destProperties = await destBlob.GetPropertiesAsync();
                    log.LogInformation($"Destination value {destProperties.Value.CopyStatus}");
                    return destBlob;
                }
            }
            catch (RequestFailedException ex)
            {
                log.LogError($"RequestFailedException: {ex.Message}", ex?.StackTrace, info);
                log.LogError(ex.StackTrace);
                throw;
            }

            return null;
        }

        public static Uri GetServiceSASUriForContainer(this BlobContainerClient containerClient, string storedPolicyName, ILogger log)
        {
            // Check whether this BlobContainerClient object has been authorized with Shared Key.
            if (containerClient.CanGenerateSasUri)
            {
                // Create a SAS token that's valid for one hour.
                BlobSasBuilder sasBuilder = new BlobSasBuilder()
                {
                    BlobContainerName = containerClient.Name,
                    Resource = "c"
                };

                if (storedPolicyName == null)
                {
                    sasBuilder.ExpiresOn = DateTimeOffset.UtcNow.AddHours(1);
                    sasBuilder.SetPermissions(BlobContainerSasPermissions.Read);
                }
                else
                {
                    sasBuilder.Identifier = storedPolicyName;
                }

                Uri sasUri = containerClient.GenerateSasUri(sasBuilder);
                log.LogInformation("SAS URI for blob container is: {0}", sasUri);

                return sasUri;
            }
            else
            {
                log.LogInformation(@"BlobContainerClient must be authorized with Shared Key credentials to create a service SAS.");
                return null;
            }
        }

        public static Uri GetServiceSASUriForBlob(this BlobClient blobClient, string containerName, string storedPolicyName, ILogger log)
        {
            // Check whether this BlobClient object has been authorized with Shared Key.
            if (blobClient.CanGenerateSasUri)
            {
                // Create a SAS token that's valid for one hour.
                BlobSasBuilder sasBuilder = new BlobSasBuilder()
                {
                    BlobContainerName = containerName,
                    BlobName = blobClient.Name,
                    Resource = "b"
                };

                if (storedPolicyName == null)
                {
                    sasBuilder.ExpiresOn = DateTimeOffset.UtcNow.AddHours(1);
                    sasBuilder.SetPermissions(BlobSasPermissions.Read |
                        BlobSasPermissions.Write);
                }
                else
                {
                    sasBuilder.Identifier = storedPolicyName;
                }

                Uri sasUri = blobClient.GenerateSasUri(sasBuilder);
                log.LogInformation("SAS URI for blob is: {0}", sasUri);

                return sasUri;
            }
            else
            {
                log.LogInformation(@"BlobClient must be authorized with Shared Key credentials to create a service SAS.");
                return null;
            }
        }
    }
}
