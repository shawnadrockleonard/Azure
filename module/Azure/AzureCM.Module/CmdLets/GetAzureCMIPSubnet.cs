using AzureCM.Module.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.CmdLets
{
    /// <summary>
    /// Provides a network topology break down for isolating IP ranges
    /// </summary>
    /// <example>
    /// Get-AzureCMIPSubnet -IPAddress 192.168.8.2
    /// Get-AzureCMIPSubnet -IPAddress 192.168.8.2/16 
    /// Get-AzureCMIPSubnet -IPAddress 192.168.8.2 -Netmask 255.255.255.(0,128,192,252,254,255)  
    /// Get-AzureCMIPSubnet -IPAddress 192.168.8.2 -CidrMask 25
    /// </example>
    [Cmdlet("Get", "AzureCMIPSubnet")]
    [CmdletHelp("Returns a IP netmask", Category = "Base Cmdlets")]
    public class GetAzureCMIPSubnet : AzureCmdlet
    {
        [Parameter(ParameterSetName = "OutputString", Mandatory = true, Position = 1)]
        public string IPAddress { get; set; }

        [Parameter(Mandatory = false)]
        public string Netmask { get; set; }

        [Parameter(Mandatory = false)]
        public byte? CidrMask { get; set; }


        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();

            try
            {
                IPNetwork n = null;

                if (!string.IsNullOrEmpty(Netmask))
                {
                    n = IPNetwork.Parse(IPAddress, Netmask);
                }
                else if (CidrMask.HasValue)
                {
                    n = IPNetwork.Parse(IPAddress, CidrMask.Value);
                }
                else
                {
                    n = IPNetwork.Parse(IPAddress);
                }

                LogVerbose("Ip Address {0} with Mask {1} value add", n.FirstUsable, n.Cidr, n);
                WriteObject(n);
            }
            catch (Exception ex)
            {
                LogError(ex, ErrorCategory.ResourceUnavailable, "Failed to calculate CIDR for {0}", IPAddress);
            }
        }
    }
}
