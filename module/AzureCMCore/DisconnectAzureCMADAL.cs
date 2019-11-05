using AzureCMCore.Base;
using AzureCMCore.oAuth;
using System;
using System.Linq;
using System.Management.Automation;
using System.Globalization;

namespace AzureCMCore
{

    [Cmdlet("Disconnect", "AzureCMADAL")]
    [CmdletHelp("Walks through disconnecting Azure AD tokens", Category = "Base Cmdlets")]
    public class DisconnectAzureCMADAL : AzureCmdlet
    {
        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            if (AzureADALConnection.CurrentConnection != null)
            {
                AzureADALConnection.CurrentConnection.Clear();
                AzureADALConnection.CurrentConnection = null;
            }

            Information($"Disconnected at {DateTime.UtcNow.ToString("f", CultureInfo.CurrentCulture)}");
        }
    }

}