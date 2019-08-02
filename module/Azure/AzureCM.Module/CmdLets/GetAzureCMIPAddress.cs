using AzureCM.Module.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
{
    /// <summary>
    /// Provides a the current IP range
    /// </summary>
    /// <example>
    /// Get-AzureCMIPAddress
    /// </example>
    [Cmdlet("Get", "AzureCMIPAddress")]
    [CmdletHelp("Returns a IP netmask", Category = "Base Cmdlets")]
    public class GetAzureCMIPAddress : AzureCmdlet
    {
        [Parameter(Mandatory = false)]
        public string WebUrl { get; set; }

        [Parameter(Mandatory = false)]
        public byte? CidrMask { get; set; }

        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();

            Uri WebUri = null;
            byte CidrMaskIpAddress = 32;
            if (string.IsNullOrEmpty(WebUrl))
            {
                WebUrl = "http://checkip.dyndns.com/";
            }
            if (CidrMask.HasValue)
            {
                CidrMaskIpAddress = CidrMask.Value;
            }

            WebUri = new Uri(WebUrl);
            var WebHostUrl = WebUri.Host;
            var ipregex = @"(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)";

            try
            {
                var webrequest = (HttpWebRequest)WebRequest.Create(WebUrl);
                webrequest.Host = WebHostUrl;
                using (var gr = webrequest.GetResponse())
                {
                    using (var gresponse = gr.GetResponseStream())
                    {
                        using (var sr = new System.IO.StreamReader(gresponse))
                        {
                            var result = sr.ReadToEnd();
                            if (Regex.IsMatch(result, ipregex))
                            {
                                var ipaddressmatches = Regex.Match(result, ipregex);
                                var n = IPNetwork.Parse(ipaddressmatches.Value, CidrMaskIpAddress);
                                LogVerbose("Ip Address {0} with Mask {1} value add", n.FirstUsable, n.Cidr, n);
                                WriteObject(n);
                            }

                        }
                    }
                }
            }
            catch (Exception ex)
            {
                LogError(ex, ErrorCategory.ResourceUnavailable, "Failed to calculate current IP from URL:{0}", WebUrl);
            }
        }
    }
}
