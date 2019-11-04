using Microsoft.Graph;
using Microsoft.Identity.Client;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace AzureCMCore.oAuth
{
    /// <summary>
    /// This class encapsulates the details of getting a token from MSAL and exposes it via the 
    /// IAuthenticationProvider interface so that GraphServiceClient or AuthHandler can use it.
    /// </summary>
    /// A significantly enhanced version of this class will in the future be available from
    /// the GraphSDK team. It will support all the types of Client Application as defined by MSAL.
    public class GraphMsalAuthenticationProvider : IAuthenticationProvider
    {
        private readonly IClientApplicationBase _clientApplication;
        private readonly string[] _scopes;

        public GraphMsalAuthenticationProvider(IClientApplicationBase clientApplication, string[] scopes)
        {
            _clientApplication = clientApplication;
            _scopes = scopes;
        }

        /// <summary>
        /// Update HttpRequestMessage with credentials
        /// </summary>
        public async Task<AuthenticationResult> AuthenticationTokenAsync()
        {
            AuthenticationResult authentication = null;
            if (_clientApplication.GetType() == typeof(PublicClientApplication))
            {
                authentication = await GetAuthenticationAsync();
            }
            else if (_clientApplication.GetType() == typeof(ConfidentialClientApplication))
            {
                authentication = await GetAuthenticationDaemonAsync();
            }

            return authentication;
        }

        /// <summary>
        /// Update HttpRequestMessage with credentials
        /// </summary>
        public async Task AuthenticateRequestAsync(HttpRequestMessage request)
        {
            AuthenticationResult authentication = await AuthenticationTokenAsync();
            request.Headers.Authorization = AuthenticationHeaderValue.Parse(authentication.CreateAuthorizationHeader());
        }

        /// <summary>
        /// Acquire Token for user
        /// </summary>
        public async Task<AuthenticationResult> GetAuthenticationAsync()
        {
            AuthenticationResult authResult;
            var application = _clientApplication as PublicClientApplication;

            try
            {
                var accounts = await application.GetAccountsAsync();
                authResult = await application.AcquireTokenSilent(_scopes, accounts.FirstOrDefault()).ExecuteAsync();
            }
            catch (MsalUiRequiredException ex)
            {
                TraceLogger.Error($"MSAL Error {ex}");
                try
                {
                    authResult = await application.AcquireTokenInteractive(_scopes).WithPrompt(Microsoft.Identity.Client.Prompt.SelectAccount).ExecuteAsync();
                }
                catch (MsalException aex)
                {
                    TraceLogger.Error($"MSAL AcquireTokenByIntegratedWindowsAuth {aex}");
                    throw;
                }
            }

            return authResult;
        }

        /// <summary>
        /// Acquire Token for confidential client [daemon]
        /// </summary>
        public async Task<AuthenticationResult> GetAuthenticationDaemonAsync()
        {
            var application = _clientApplication as ConfidentialClientApplication;

            try
            {
                var authResult = await application.AcquireTokenForClient(_scopes).ExecuteAsync();
                return authResult;
            }
            catch (MsalException ex)
            {
                TraceLogger.Error($"MSAL Error {ex}");
                throw;
            }
        }

    }
}

