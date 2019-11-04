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
    [Cmdlet("Get", "AzureCMConfig")]
    [CmdletHelp("Returns a JSON Config document including VM details", Category = "Base Cmdlets")]
    public class GetAzureCMConfig : AzureCmdlet
    {
        [Parameter(ParameterSetName = "OutputString", Mandatory = true, Position = 1)]
        public string WebUri { get; set; }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            var stamp = DateTime.Now.ToString("s", CultureInfo.CurrentCulture);
            Information($"[{stamp}] {WebUri}");

            try
            {
                var webrequest = System.Net.WebRequest.Create(WebUri);
                using (var gr = webrequest.GetResponse())
                {
                    using (var gresponse = gr.GetResponseStream())
                    {
                        using (var sr = new System.IO.StreamReader(gresponse))
                        {
                            var result = sr.ReadToEnd();
                            WriteObject(result);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Failed to retreive JSON from storage
                Error(ex, ErrorCategory.ResourceUnavailable, Properties.Resources.StorageReadFailure, WebUri);
            }
        }
    }
}
