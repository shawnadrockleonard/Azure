using Microsoft.Azure.Management.Fluent;

namespace AzQueueProcessor.Common.Extensions
{
    public interface IManagedIdentityExtensions
    {
        IAzure GetAzureCredentials();
    }
}