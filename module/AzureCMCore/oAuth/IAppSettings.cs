using Microsoft.Identity.Client;
using System;
using System.Collections.Generic;
using System.Text;

namespace AzureCMCore.oAuth
{
    /// <summary>
    /// Represents the Application Config AppSettings
    /// </summary>
    public interface IAppSettings
    {
        /// <summary>
        /// Gets or sets the PostLogoutRedirectURI for Active Directory authentication. The Post Logout Redirect Uri is the URL where the user will be redirected after they have signed out
        /// </summary>
        string PostLogoutRedirectURI { get; set; }

        /// <summary>
        /// Gets or sets the application ID for Active Directory authentication. The Client ID is used by the application to uniquely identify itself to Azure AD.
        /// </summary>
        string ClientId { get; set; }

        /// <summary>
        /// Gets or sets the client secret for Active Directory authentication. The ClientSecret is a credential used to authenticate the application to Azure AD.  Azure AD supports password and certificate credentials.
        /// </summary>
        string ClientSecret { get; set; }

        /// <summary>
        /// Gets or Sets the Login endpoint for Azure identities
        /// </summary>
        string AzureLoginUrl { get; set; }

        /// <summary>
        /// Gets or sets the Tenant Domain
        /// </summary>
        string TenantDomain { get; set; }

        /// <summary>
        /// Gets or sets the Tenant Id
        /// </summary>
        string TenantId { get; set; }

        /// <summary>
        /// Returns the full URI endpoint for Azure Authentication
        /// </summary>
        string Authority { get; }

        string Audience { get; set; }

        /// <summary>
        /// Represents the Azure AD Group claim to which the system should be locked down
        /// </summary>
        string SecurityGroupId { get; set; }


        string[] MSALScopes { get; set; }

        AzureCloudInstance AzureCloudInstance { get; }

        AadAuthorityAudience AadAuthorityAudience { get; }
    }
}
