using Azure.Identity;
using Microsoft.Extensions.Configuration;
using System;
using System.Linq;
using System.Security.Cryptography.X509Certificates;

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
                        AuthorityHost = AzureAuthorityHosts.AzurePublicCloud
                    };
                    var clientCertificate = GetCertificate(clientSecret);
                    var credentials = new Azure.Identity.ClientCertificateCredential(tenantId, clientId, clientCertificate, tokenOptions);
                    builder.AddAzureKeyVault(new Uri(vaultUri), credentials);
                }
                else
                {
                    Console.WriteLine($"attempting to add KeyVault {vaultUri}");
                    builder.AddAzureKeyVault(new Uri(vaultUri), ManagedIdentityExtensions.GetMsiCredential());
                }
            }
        }


        public static X509Certificate2 GetCertificate(string subjectAlternativeName)
        {
            using X509Store store = new(StoreName.My, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadOnly);

            var certs = store.Certificates.Find(X509FindType.FindBySubjectName, subjectAlternativeName, false);

            if (certs.Count == 0)
            {
                throw new InvalidOperationException($"Unable to find client cert with subject name '{subjectAlternativeName}'");
            }

            var clientCert = certs.Cast<X509Certificate2>().OrderBy(x => x.NotAfter).Last();

            return clientCert;
        }
    }
}