using System;
using System.Collections.Generic;
using System.Text;

namespace AzureCMCore.oAuth
{
    public static class AzureADConstants
    {
        /// <summary>
        /// SAML/AzureAD Claim identifier for the Azure AD Tenant
        /// </summary>
        public const string TenantIdClaimType = "http://schemas.microsoft.com/identity/claims/tenantid";

        /// <summary>
        /// SAML/AzureAD Claim Identifier for the user/group ID
        /// </summary>
        public const string ObjectIdClaimType = "http://schemas.microsoft.com/identity/claims/objectidentifier";

        /// <summary>
        /// Inject into the Authority URI to ensure its a multi-tenant application
        /// </summary>
        public const string Common = "common";

        /// <summary>
        /// Multi-Tenant authentication admin consent enables Azure AD Administrators to accept the app
        /// </summary>
        public const string AdminConsent = "admin_consent";

        /// <summary>
        /// Prefixed claim identifier
        /// </summary>
        public const string Issuer = "iss";

        /// <summary>
        /// OAuth common endpoint supports Multi-Tenant authentication
        /// </summary>
        public const string AuthorityCommon = "https://login.windows.net/common/oauth2/token";

        /// <summary>
        /// OAuth endpoint for a specific tenant
        /// </summary>
        public const string AuthorityTenantFormat = "https://login.windows.net/{0}/oauth2/token?api-version=1.0";

        /// <summary>
        /// MSA supported endpoint
        /// </summary>
        public const string AuthorityFormat = "https://login.microsoftonline.com/{0}";

        /// <summary>
        /// Call back for Client token services
        /// </summary>
        public const string CallbackPath = "/signin-oidc";

        /// <summary>
        /// MS Graph EndPoint URI
        /// </summary>
        public const string GraphResourceId = "https://graph.microsoft.com";

        /// <summary>
        /// MS Graph API Endpoint
        /// </summary>
        public const string GraphApiVersion = "1.6";

        /// <summary>
        /// Office 365 management endpoint
        /// </summary>
        public const string O365ResourceId = "https://manage.office.com";

        /// <summary>
        /// Common end-point for Microsoft Online Services. You should no longer use https://login.windows.net
        /// </summary>
        public const string CommonAuthority = "https://login.microsoftonline.com/common/";

        /// <summary>
        /// Endpoint for the Microsoft Azure AD endpoint
        /// </summary>
        public const string GraphServiceUrl = "https://graph.windows.net";


        public const string O365UnifiedAPIResource = @"https://graph.microsoft.com/";


        internal const string ActiveDirectoryAuthenticationServiceUrl = "https://login.microsoftonline.com/common/oauth2/authorize";

        internal const string ActiveDirectorySignOutUrl = "https://login.microsoftonline.com/common/oauth2/logout";

        internal const string ActiveDirectoryTokenServiceUrl = "https://login.microsoftonline.com/common/oauth2/token";

        public const string NameClaimType = "name";

        public const string IssuerClaim = "iss";

        public const string TenantAuthority = "https://login.microsoftonline.com/{0}/oauth2/v2.0/token";

        public const string Authority = "https://login.microsoftonline.com/common/v2.0/";

         public const string MicrosoftGraphGroupsApi = "https://graph.microsoft.com/v1.0/groups";

        public const string MicrosoftGraphUsersApi = "https://graph.microsoft.com/v1.0/users";

        public const string AdminConsentFormat = "https://login.microsoftonline.com/{0}/adminconsent?client_id={1}&state={2}&redirect_uri={3}";

        public const string MSGraphScope = "https://graph.microsoft.com/.default";
    }
}
