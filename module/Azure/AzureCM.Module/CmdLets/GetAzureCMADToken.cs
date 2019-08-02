using AzureCM.Module.Base;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
{
    [Cmdlet("Get", "AzureCMADToken")]
    [CmdletHelp("Returns a token which can be used for further authentication", Category = "Base Cmdlets")]
    public class GetAzureCMADToken : AzureCmdlet
    {
        [Parameter(Mandatory = false, HelpMessage = "The tenant id for the Azure AD instance.")]
        public string TenantId { get; set; }

        [Parameter(Mandatory = false, HelpMessage = "The client id associated with the tenant.")]
        public string ClientId { get; set; }

        [Parameter(Mandatory = false)]
        public string ReplyUrl { get; set; }

        [Parameter(Mandatory = false)]
        [ValidateSet(new string[] { "Azure", "AzureUSGovernment" }, IgnoreCase = true)]
        public string Environment { get; set; }



        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();

            Collection<PSObject> results = new Collection<PSObject>();

            var tenantId = (String.IsNullOrEmpty(TenantId) ? GetAppSetting("TenantId") : TenantId);
            var clientId = (String.IsNullOrEmpty(ClientId) ? GetAppSetting("ClientId") : ClientId);
            var authUrl = GetAppSetting("AuthUrl");
            var header = GetAuthorizationHeader(tenantId, authUrl, clientId);
            if (header != null)
            {
                LogVerbose("Header: {0}", header.AccessToken);

                var newitem = new
                {
                    RefreshToken = header.RefreshToken,
                    AccessToken = header.AccessToken,
                    AccessTokenType = header.AccessTokenType,
                    ExpiresOn = header.ExpiresOn
                };
                var ps = PSObject.AsPSObject(newitem);
                results.Add(ps);

                WriteObject(results, true);
            }
        }

        private AuthenticationResult GetAuthorizationHeader(string tenantId, string authUrlHost, string clientId)
        {
            AuthenticationResult result = null;

            try
            {
                var authUrl = String.Format(authUrlHost + "/{0}", tenantId);
                var context = new AuthenticationContext(authUrl);


                result = context.AcquireToken(
                    resource: "https://management.core.windows.net/",
                    clientId: clientId,
                    redirectUri: new Uri("urn:ietf:wg:oauth:2.0:oob"),
                    promptBehavior: PromptBehavior.Auto);

            }
            catch (Exception threadEx)
            {
                LogError(threadEx, ErrorCategory.FromStdErr, "Failed to authenticate: {0}", threadEx.Message);
            }

            return result;
        }
    }
}