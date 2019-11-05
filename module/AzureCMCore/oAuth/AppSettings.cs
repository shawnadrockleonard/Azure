using Microsoft.Identity.Client;
using System;
using System.Collections.Generic;
using System.Text;

namespace AzureCMCore.oAuth
{
    /// <summary>
    /// Domain Model for the Application Config
    /// </summary>
    public class AppSettings : IAppSettings
    {
        /// <summary>
        /// Gets or sets the PostLogoutRedirectURI for Active Directory authentication. The Post Logout Redirect Uri is the URL where the user will be redirected after they have signed out
        /// </summary>
        public string PostLogoutRedirectURI { get; set; }

        /// <summary>
        /// Gets or sets the application ID for Active Directory authentication. The Client ID is used by the application to uniquely identify itself to Azure AD.
        /// </summary>
        public string ClientId { get; set; }

        /// <summary>
        /// Gets or sets the client secret for Active Directory authentication. The ClientSecret is a credential used to authenticate the application to Azure AD.  Azure AD supports password and certificate credentials.
        /// </summary>
        public string ClientSecret { get; set; }

        /// <summary>
        /// Represents the Azure AD Group claim to which the system should be locked down
        /// </summary>
        public string SecurityGroupId { get; set; }

        /// <summary>
        /// Gets or Sets the Login endpoint for Azure identities
        /// </summary>
        public string AzureLoginUrl { get; set; }

        /// <summary>
        /// Gets or sets the Tenant Domain
        /// </summary>
        public string TenantDomain { get; set; }

        /// <summary>
        /// Gets or sets the Tenant Id
        /// </summary>
        public string TenantId { get; set; }

        /// <summary>
        /// <seealso cref="IAppSettings.Authority"/>
        /// </summary>
        public string Authority
        {
            get
            {
                if (string.IsNullOrEmpty(AzureLoginUrl))
                    return string.Empty;
                var AADLogin = new Uri(AzureLoginUrl);
                var AuthorityUri = new Uri(AADLogin, TenantDomain).AbsoluteUri;
                return AuthorityUri;
            }
        }

        /// <summary>
        /// TODO
        /// </summary>
        public string ServiceResource { get; set; }

        /// <summary>
        /// Scoping
        /// </summary>
        public string Audience { get; set; }

        /// <summary>
        /// v2 ADAL Scopes 
        /// </summary>
        /// <example>
        /// openid profile email offline_access user.readbasic.all
        /// </example>
        public string[] MSALScopes { get; set; }

        public AzureCloudInstance AzureCloudInstance { get; set; }

        public AadAuthorityAudience AadAuthorityAudience { get; set; }
    }
}
