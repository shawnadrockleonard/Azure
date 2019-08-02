using AzureCM.Module.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
{
    [Cmdlet("Get", "AzureCMConfig")]
    [CmdletHelp("Returns a JSON Config document including VM details", Category = "Base Cmdlets")]
    public class GetAzureCMConfig : AzureCmdlet
    {
        [Parameter(ParameterSetName = "OutputString", Mandatory = true, Position = 1)]
        public string WebUri { get; set; }

        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();
            var stamp = DateTime.Now.ToString("s");
            LogVerbose("[{0}] {1}", stamp, WebUri);

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
                LogError(ex, ErrorCategory.ResourceUnavailable, "Failed to retreive config from storage {0}", WebUri);
            }
        }
    }
}
