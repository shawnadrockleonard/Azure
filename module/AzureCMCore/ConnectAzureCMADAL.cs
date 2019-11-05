using AzureCMCore.Base;
using AzureCMCore.oAuth;
using System.Linq;
using System.Management.Automation;

namespace AzureCMCore
{
    [Cmdlet("Connect", "AzureCMADAL")]
    [CmdletHelp("Walks through connecting to Azure AD for tokens", Category = "Base Cmdlets")]
    public class ConnectAzureCMADAL : AzureCmdlet
    {
        [Parameter(Mandatory = false, HelpMessage = "The array of permission scopes for the Microsoft Graph API.", ParameterSetName = "Scope")]
        public string[] Scopes { get; set; } = System.Array.Empty<string>();

        [Parameter(Mandatory = false, HelpMessage = "The URI of the resource to query")]
        public string ResourceUri { get; set; }


        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            var useInteractiveLogin = true;
            var ilogger = new DefaultUsageLogger(Information, Warning, Error);

            if (Scopes == null || !Scopes.Any())
            {
                useInteractiveLogin = false;
                Scopes = new string[] { AzureADConstants.MSGraphScope };
            }

            AuthenticationSettings.PostLogoutRedirectURI = this.ResourceUri ?? AzureADConstants.GraphResourceId;
            AuthenticationSettings.MSALScopes = Scopes;

            // Get back the Access Token and the Refresh Token
            var AzureADCache = new AzureADv2TokenCache(AuthenticationSettings, ilogger, useInteractiveLogin);
            AzureADALConnection.CurrentConnection = new AzureADALConnection(AzureADCache, AuthenticationSettings, ilogger);

            // Write Tokens to Console
            WriteObject(AzureADALConnection.CurrentConnection.AuthenticationResult);
        }
    }
}
