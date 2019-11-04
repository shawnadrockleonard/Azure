using AzureCMCore.Base;
using AzureCMCore.oAuth;
using System;
using System.Linq;
using System.Management.Automation;

namespace AzureCMCore
{
    [Cmdlet("Connect", "AzureCMADAL")]
    [CmdletHelp("Walks through connecting to Azure AD for tokens", Category = "Base Cmdlets")]
    public class ConnectAzureCMADAL : AzureCmdlet
    {
        [Parameter(Mandatory = true, HelpMessage = "The array of permission scopes for the Microsoft Graph API.", ParameterSetName = "Scope")]
        public String[] Scopes { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The client id of the app which gives you access to the Microsoft Graph API.", ParameterSetName = "Scope")]
        public string MSALClientId { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The client id of the app which gives you access to the Microsoft Graph API.", ParameterSetName = "AAD")]
        public string AppId { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The app key of the app which gives you access to the Microsoft Graph API.", ParameterSetName = "AAD")]
        public string AppSecret { get; set; }

        [Parameter(Mandatory = true, HelpMessage = "The AAD where the O365 app is registred. Eg.: contoso.com, or contoso.onmicrosoft.com.")]
        public string AADDomain { get; set; }

        [Parameter(Mandatory = false, HelpMessage = "The URI of the resource to query")]
        public string ResourceUri { get; set; }


        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            var AADLoginURI = GetAppSetting("AADLoginEndPoint");
            AppSettings config = null;
            var useInteractiveLogin = true;

            var ilogger = new DefaultUsageLogger(Information, Warning, Error);

            if (Scopes == null || !Scopes.Any())
            {
                useInteractiveLogin = false;
                Scopes = new string[] { AzureADConstants.MSGraphScope };
            }

            config = new AppSettings()
            {
                AzureLoginUrl = AADLoginURI,
                ClientID = this.AppId,
                ClientSecret = this.AppSecret,
                PostLogoutRedirectURI = this.ResourceUri ?? AzureADConstants.GraphResourceId,
                TenantDomain = this.AADDomain,
                TenantId = "",
                MSALClientID = this.MSALClientId,
                MSALScopes = Scopes
            };

            // Get back the Access Token and the Refresh Token
            var AzureADCache = new AzureADv2TokenCache(config, ilogger, useInteractiveLogin);
            AzureADALConnection.CurrentConnection = new AzureADALConnection(AzureADCache, config, ilogger);

            // Write Tokens to Console
            WriteObject(AzureADALConnection.CurrentConnection.AuthenticationResult);
        }
    }
}
