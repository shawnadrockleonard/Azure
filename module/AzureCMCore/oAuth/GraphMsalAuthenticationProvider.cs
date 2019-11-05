using Microsoft.Identity.Client;
using System;
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
    public class GraphMsalAuthenticationProvider : Microsoft.Graph.IAuthenticationProvider
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
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }
            AuthenticationResult authentication = await AuthenticationTokenAsync();
            request.Headers.Authorization = AuthenticationHeaderValue.Parse(authentication.CreateAuthorizationHeader());
        }

        /// <summary>
        /// Acquire Token for user
        /// </summary>
        public async Task<AuthenticationResult> GetAuthenticationAsync()
        {
            AuthenticationResult authResult = null;
            var application = _clientApplication as PublicClientApplication;

            var accounts = await application.GetAccountsAsync();
            if (accounts.Any())
            {
                try
                {
                    authResult = await application.AcquireTokenSilent(_scopes, accounts.FirstOrDefault())
                    .ExecuteAsync();
                }
                catch (MsalUiRequiredException ex)
                {
                    TraceLogger.Error($"MSAL Error {ex}");
                }
            }

            if (authResult == null)
            {
                try
                {
                    authResult = application.AcquireTokenWithDeviceCode(_scopes, 
                         (deviceCodeCallback) =>
                         {
                             Console.WriteLine(deviceCodeCallback.Message);
                             return Task.FromResult(0);
                         }).ExecuteAsync().GetAwaiter().GetResult();
                    TraceLogger.Information($"Username from Device Code Flow {authResult?.Account?.Username}");
                }
                catch (MsalServiceException aex)
                {
                    TraceLogger.Error($"MsalServiceException AcquireTokenWithDeviceCode {aex}");
                    throw;
                }
                catch (OperationCanceledException ex)
                {
                    // If you use a CancellationToken, and call the Cancel() method on it, then this *may* be triggered
                    // to indicate that the operation was cancelled. 
                    // See https://docs.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads 
                    // for more detailed information on how C# supports cancellation in managed threads.
                    TraceLogger.Error($"OperationCanceledException AcquireTokenWithDeviceCode {ex}");
                }
                catch (MsalClientException ex)
                {
                    // Possible cause - verification code expired before contacting the server
                    // This exception will occur if the user does not manage to sign-in before a time out (15 mins) and the
                    // call to `AcquireTokenWithDeviceCode` is not cancelled in between
                    TraceLogger.Error($"MsalClientException AcquireTokenWithDeviceCode {ex}");
                }
            }

            return authResult;
        }


        private async Task<AuthenticationResult> GetTokenForWebApiUsingIntegratedWindowsAuthenticationAsync(PublicClientApplication application, string[] scopes)
        {
            AuthenticationResult result = null;
            try
            {
                result = await application.AcquireTokenByIntegratedWindowsAuth(scopes)
                    .ExecuteAsync();
            }
            catch (MsalUiRequiredException ex) when (ex.Message.Contains("AADSTS65001"))
            {
                // MsalUiRequiredException: AADSTS65001: The user or administrator has not consented to use the application 
                // with ID '{appId}' named '{appName}'.Send an interactive authorization request for this user and resource.

                // you need to get user consent first. This can be done, if you are not using .NET Core (which does not have any Web UI)
                // by doing (once only) an AcquireTokenAsync interactive.

                // If you are using .NET core or don't want to do an AcquireTokenInteractive, you might want to suggest the user to navigate
                // to a URL to consent: https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id={clientId}&response_type=code&scope=user.read
                throw;
            }
            catch (MsalServiceException)
            {
                // Kind of errors you could have (in ex.Message)

                // MsalServiceException: AADSTS90010: The grant type is not supported over the /common or /consumers endpoints. Please use the /organizations or tenant-specific endpoint.
                // you used common.
                // Mitigation: as explained in the message from Azure AD, the authoriy needs to be tenanted or otherwise organizations

                // MsalServiceException: AADSTS70002: The request body must contain the following parameter: 'client_secret or client_assertion'.
                // Explanation: this can happen if your application was not registered as a public client application in Azure AD 
                // Mitigation: in the Azure portal, edit the manifest for your application and set the `allowPublicClient` to `true` 
                throw;
            }
            catch (MsalClientException)
            {
                // Error Code: unknown_user Message: Could not identify logged in user
                // Explanation: the library was unable to query the current Windows logged-in user or this user is not AD or AAD 
                // joined (work-place joined users are not supported). 

                // Mitigation 1: on UWP, check that the application has the following capabilities: Enterprise Authentication, 
                // Private Networks (Client and Server), User Account Information

                // Mitigation 2: Implement your own logic to fetch the username (e.g. john@contoso.com) and use the 
                // AcquireTokenByIntegratedWindowsAuthAsync overload that takes in the username
                throw;
            }
            return result;
        }

        /// <summary>
        /// Acquire Token for confidential client [daemon]
        /// </summary>
        public async Task<AuthenticationResult> GetAuthenticationDaemonAsync()
        {
            var application = _clientApplication as ConfidentialClientApplication;

            try
            {
                var authResult = await application.AcquireTokenForClient(_scopes).ExecuteAsync().ConfigureAwait(true);
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

