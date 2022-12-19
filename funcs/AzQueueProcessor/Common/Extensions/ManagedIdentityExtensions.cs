using Azure.Core;
using Azure.Identity;
using AzQueueProcessor.Common.Models;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Authentication;
using Microsoft.Extensions.Options;

namespace AzQueueProcessor.Common.Extensions
{
    public class ManagedIdentityExtensions : IManagedIdentityExtensions
    {
        public ManagedIdentityExtensions(IOptions<ManagedCredentials> credentials)
        {
            AzCredentials = credentials.Value;
        }

        public static TokenCredential GetMsiCredential()
        {
            var options = new DefaultAzureCredentialOptions()
            {
                AuthorityHost = AzureAuthorityHosts.AzureGovernment,
                ExcludeVisualStudioCredential = false
            };

            return new DefaultAzureCredential(options);
        }

        private readonly ManagedCredentials AzCredentials;

        public IAzure GetAzureCredentials()
        {
            if (!string.IsNullOrWhiteSpace(AzCredentials?.ClientId))
            {
                var credentials = SdkContext.AzureCredentialsFactory
                    .FromServicePrincipal(AzCredentials.ClientId, AzCredentials.ClientSecret, AzCredentials.TenantId, AzureEnvironment.AzureUSGovernment);

                return Microsoft.Azure.Management.Fluent.Azure.Authenticate(credentials).WithSubscription(AzCredentials?.SubscriptionId);
            }
            else
            {
                var credentials = SdkContext.AzureCredentialsFactory
                    .FromSystemAssignedManagedServiceIdentity(MSIResourceType.AppService, AzureEnvironment.AzureUSGovernment);

                return Microsoft.Azure.Management.Fluent.Azure.Authenticate(credentials).WithDefaultSubscription();
            }
        }
    }
}
