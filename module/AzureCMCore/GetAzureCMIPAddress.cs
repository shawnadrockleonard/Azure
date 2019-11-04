using AzureCMCore.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace AzureCMCore
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

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            byte CidrMaskIpAddress = 32;
            if (string.IsNullOrEmpty(WebUrl))
            {
                WebUrl = "http://checkip.dyndns.com/";
            }
            if (CidrMask.HasValue)
            {
                CidrMaskIpAddress = CidrMask.Value;
            }

            Uri WebUri = new Uri(WebUrl);
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
                                Information($"Ip Address {n.FirstUsable} with Mask {n.Cidr} value add {n}");
                                WriteObject(n);
                            }

                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Error(ex, ErrorCategory.ResourceUnavailable, Properties.Resources.IPNetworkCalculateFailure, WebUrl);
            }
        }
    }
}
