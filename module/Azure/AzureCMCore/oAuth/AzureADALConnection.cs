using System;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Linq;

namespace AzureCMCore.oAuth
{
    public class AzureADALConnection
    {
        public static AzureADALConnection CurrentConnection { get; set; }

        /// <summary>
        /// Holds the OAuth 2.0 Authentication Result
        /// </summary>
        public string AuthenticationResult
        {
            get
            {
                return GetTokenAsyncResult();
            }
        }

        public IAppSettings AzureADCredentials { get; protected set; }

        public IOAuthTokenCache AzureADCache { get; protected set; }

        protected readonly ITraceLogger _iLogger;

        /// <summary>
        /// Initialize the Azure AD Connection with config and diagnostics
        /// </summary>
        /// <param name="oAuthTokenCache"></param>
        /// <param name="azureADCredentials"></param>
        /// <param name="traceLogger"></param>
        public AzureADALConnection(IOAuthTokenCache oAuthTokenCache, IAppSettings azureADCredentials, ITraceLogger traceLogger)
        {
            _iLogger = traceLogger;
            AzureADCredentials = azureADCredentials;
            AzureADCache = oAuthTokenCache;
        }
        /// <summary>
        /// Initiates a blocker and waites for a Async thread to complete
        /// </summary>
        /// <returns></returns>
        internal string GetTokenAsyncResult()
        {
            string bearerToken = null;
            try
            {
                bearerToken = AzureADCache.AccessTokenAsync(string.Empty).GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                _iLogger.LogError(ex, $"Claiming Azure AD Token Failed {ex.Message}");
            }

            if (string.IsNullOrEmpty(bearerToken))
            {
                throw new ArgumentException($"AzureAD Cache has no Bearer Token");
            }

            return bearerToken;
        }

        public bool IsExpired()
        {
            return AzureADCache.IsTokenExpired();
        }

        private static X509Certificate2 ReadCertificateFromStore(string thumbprint)
        {
            X509Certificate2 cert = null;
            var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadOnly);
            X509Certificate2Collection certCollection = store.Certificates;
            X509Certificate2Collection currentCerts = certCollection.Find(X509FindType.FindByTimeValid, DateTime.Now, false);
            X509Certificate2Collection signingCert = currentCerts.Find(X509FindType.FindByThumbprint, thumbprint, false);
            cert = signingCert.OfType<X509Certificate2>().OrderByDescending(c => c.NotBefore).FirstOrDefault();
            store.Close();
            return cert;
        }
    }
}
