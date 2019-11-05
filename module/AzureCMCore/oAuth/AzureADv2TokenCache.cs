using Microsoft.Identity.Client;
using System;
using System.Globalization;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace AzureCMCore.oAuth
{
    /// <summary>
    /// Represents a generic token cache to pull Tokens or Refresh Tokens
    /// </summary>
    public class AzureADv2TokenCache : IOAuthTokenCache
    {
        private readonly IAppSettings _aadConfig;
        private readonly GraphMsalAuthenticationProvider _authContext;
        private readonly ITraceLogger _iLogger;

        /// <summary>
        /// Represents the token to be used during authentication
        /// </summary>
        internal static AuthenticationResult AuthenticationToken { get; private set; }

        public AzureADv2TokenCache(IAppSettings aadConfig, ITraceLogger iLogger, bool useInteractiveLogin)
        {
            if (aadConfig == null)
            {
                throw new ArgumentNullException(nameof(aadConfig));
            }

            _aadConfig = aadConfig;
            _iLogger = iLogger;

            IClientApplicationBase clientApplication;
            if (useInteractiveLogin)
            {
                var publicClientApplicationOptions = new PublicClientApplicationOptions()
                {
                    AadAuthorityAudience = _aadConfig.AadAuthorityAudience,
                    AzureCloudInstance = _aadConfig.AzureCloudInstance,
                    ClientId = _aadConfig.ClientId,
                    RedirectUri = "urn:ietf:wg:oauth:2.0:oob",
                    TenantId = _aadConfig.TenantId
                };
                clientApplication = PublicClientApplicationBuilder.CreateWithApplicationOptions(publicClientApplicationOptions)
                    .Build();
            }
            else
            {
                clientApplication = ConfidentialClientApplicationBuilder.Create(_aadConfig.ClientId)
                    .WithClientSecret(_aadConfig.ClientSecret)
                    .WithAuthority(new Uri(_aadConfig.Authority))
                    .Build();
            }

            _authContext = new GraphMsalAuthenticationProvider(clientApplication, aadConfig.MSALScopes);
        }

        /// <summary>
        /// Return the Redirect URI from the AzureAD Config
        /// </summary>
        public string GetRedirect()
        {
            return _aadConfig.PostLogoutRedirectURI.ToString(CultureInfo.CurrentCulture);
        }

        /// <summary>
        /// Validate the current token in the cache
        /// </summary>
        /// <param name="redirectUri"></param>
        /// <returns></returns>
        async public Task<string> AccessTokenAsync(string redirectUri)
        {
            var result = await TryGetAccessTokenResultAsync(redirectUri);
            return result.AccessToken;
        }

        /// <summary>
        /// Will request the token, if the cache has expired, will throw an exception and request a new auth cache token and attempt to return it
        /// </summary>
        /// <param name="redirectUri">(OPTIONAL) a redirect to the resource URI</param>
        /// <returns>Return an Authentication Result which contains the Token/Refresh Token</returns>
        async private Task<AuthenticationResult> TryGetAccessTokenResultAsync(string redirectUri)
        {
            AuthenticationResult token = null; var cleanToken = false;

            try
            {
                token = await AccessTokenResultAsync();
                cleanToken = true;
            }
            catch (Exception ex)
            {
                _iLogger.LogError(ex, "AdalCacheException: {0}", ex.Message);
            }

            if (!cleanToken)
            {
                // Failed to retrieve, reup the token
                redirectUri = (string.IsNullOrEmpty(redirectUri) ? GetRedirect() : redirectUri);
                await RedeemAuthCodeForAadGraphAsync(string.Empty, redirectUri);
                token = await AccessTokenResultAsync();
            }

            return token;
        }

        /// <summary>
        /// Check the Authentication Token Expiry
        /// </summary>
        /// <returns></returns>
        public bool IsTokenExpired()
        {
            return AuthenticationToken == null
                 || AuthenticationToken.ExpiresOn <= DateTimeOffset.Now;
        }

        /// <summary>
        /// Validate the current token in the cache
        /// </summary>
        /// <returns></returns>
        async private Task<AuthenticationResult> AccessTokenResultAsync()
        {
            if (IsTokenExpired())
            {
                await RedeemAuthCodeForAadGraphAsync(string.Empty, _aadConfig.PostLogoutRedirectURI);
            }

            return AuthenticationToken;
        }

        /// <summary>
        /// clean up the db
        /// </summary>
        public void Clear()
        {
            AuthenticationToken = null;
        }


        async public Task RedeemAuthCodeForAadGraphAsync(string code, string resource_uri)
        {
            // Redeem the auth code and cache the result in the db for later use.
            var result = await _authContext.AuthenticationTokenAsync();
            AuthenticationToken = result;
        }

        /// <summary>
        /// Update HttpClient with credentials
        /// </summary>
        public async Task AuthenticateRequestAsync(HttpClient request, string redirectUri)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            AuthenticationResult authentication = await TryGetAccessTokenResultAsync(redirectUri);
            request.DefaultRequestHeaders.Authorization = AuthenticationHeaderValue.Parse(authentication.CreateAuthorizationHeader());
        }

        /// <summary>
        /// Update HttpRequestMessage with credentials
        /// </summary>
        public async Task AuthenticateRequestMessageAsync(HttpRequestMessage requestMessage, string redirectUri)
        {
            if (requestMessage == null)
            {
                throw new ArgumentNullException(nameof(requestMessage));
            }

            AuthenticationResult authentication = await TryGetAccessTokenResultAsync(redirectUri);
            requestMessage.Headers.Authorization = AuthenticationHeaderValue.Parse(authentication.CreateAuthorizationHeader());
        }
    }
}
