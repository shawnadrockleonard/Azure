using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace AzureCMCore.oAuth
{
    /// <summary>
    /// OAuth interface for claiming Tokens
    /// </summary>
    public interface IOAuthTokenCache
    {
        /// <summary>
        /// Return the Redirect URI from the AzureAD Config
        /// </summary>
        string GetRedirect();

        /// <summary>
        /// If the token is no longer fresh it will claim a new token
        /// </summary>
        /// <param name="redirectUri"></param>
        /// <returns>Access Token as a string</returns>
        Task<string> AccessTokenAsync(string redirectUri);

        /// <summary>
        ///     Acquires security token from the authority using an authorization code previously
        ///     received. This method does not lookup token cache, but stores the result in it,
        /// </summary>
        /// <param name="code"></param>
        /// <param name="redirect"></param>
        /// <returns></returns>
        Task RedeemAuthCodeForAadGraphAsync(string code, string redirect);

        /// <summary>
        /// Clears the user token cache
        /// </summary>
        void Clear();

        /// <summary>
        /// Appends the token to the <paramref name="request"/>
        /// </summary>
        /// <param name="request"></param>
        /// <param name="redirectUri">(OPTIONAL) claim the token for a specific redirect Uri</param>
        /// <returns></returns>
        Task AuthenticateRequestAsync(HttpClient request, string redirectUri);

        /// <summary>
        /// Update HttpRequestMessage with credentials
        /// </summary>
        /// <param name="requestMessage"></param>
        /// <param name="redirectUri">(OPTIONAL) claim the token for a specific redirect Uri</param>
        Task AuthenticateRequestMessageAsync(HttpRequestMessage requestMessage, string redirectUri);

        /// <summary>
        /// Returns whether the Token is Expired
        /// </summary>
        /// <returns></returns>
        bool IsTokenExpired();
    }
}