using Azure.Identity;
using Microsoft.Extensions.Configuration;
using System;

namespace AzQueueProcessor.Common.Extensions
{
    public static class KeyVaultExtensions
    {
        public static void AddKeyVault(this IConfigurationBuilder builder)
        {
            var vaultUri = Environment.GetEnvironmentVariable("VaultUri");
            if (!string.IsNullOrEmpty(vaultUri))
            {
                var builtConfig = builder.Build();
                var clientId = builtConfig["Azure:ClientId"];
                if (!string.IsNullOrWhiteSpace(clientId))
                {
                    Console.WriteLine($"attempting to add KeyVault {vaultUri} via ClientSecretCredential.");
                    var clientSecret = builtConfig["Azure:ClientSecret"];
                    var tenantId = builtConfig["Azure:TenantId"];
                    var tokenOptions = new TokenCredentialOptions()
                    {
                        AuthorityHost = AzureAuthorityHosts.AzureGovernment
                    };
                    var credentials = new Azure.Identity.ClientSecretCredential(tenantId, clientId, clientSecret, tokenOptions);
                    builder.AddAzureKeyVault(new Uri(vaultUri), credentials);
                }
                else
                {
                    Console.WriteLine($"attempting to add KeyVault {vaultUri}");
                    builder.AddAzureKeyVault(new Uri(vaultUri), ManagedIdentityExtensions.GetMsiCredential());
                }
            }
        }
    }
}