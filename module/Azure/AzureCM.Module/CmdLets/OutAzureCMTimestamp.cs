using AzureCM.Module.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
{
    [Cmdlet("Out", "AzureCMTimestamp")]
    [CmdletHelp("Write verbose message to logs", Category = "Base Cmdlets")]
    public class OutAzureCMTimestamp : AzureCmdlet
    {
        [Parameter(ParameterSetName = "OutputString", Mandatory = true, Position = 1)]
        public string Message { get; set; }

        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();
            var stamp = DateTime.Now.ToString("s");
            LogVerbose("[{0}] {1}", stamp, Message);
        }
    }
}
