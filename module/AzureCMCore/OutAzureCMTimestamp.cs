using AzureCMCore.Base;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace AzureCMCore
{
    [Cmdlet("Out", "AzureCMTimestamp")]
    [CmdletHelp("Write verbose message to logs", Category = "Base Cmdlets")]
    public class OutAzureCMTimestamp : AzureCmdlet
    {
        [Parameter(ParameterSetName = "OutputString", Mandatory = true, Position = 1)]
        public string Message { get; set; }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            var stamp = DateTime.Now.ToString("s", CultureInfo.CurrentCulture);
            Information($"[{stamp}] {Message}");
        }
    }
}
