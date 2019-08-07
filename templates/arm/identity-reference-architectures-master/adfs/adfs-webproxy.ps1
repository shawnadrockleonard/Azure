Configuration InstallWebProxyApp 
{ 
   param
    (
        [Parameter(Mandatory)]
        [string]$DomainName,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
        
        [Parameter(Mandatory)]
        [string]$FederationName,

        [Parameter(Mandatory)]
        [string]$WebApplicationProxyName
    )

    #Import the required DSC Resources
    Import-DscResource -Module xPendingReboot, cADFS
    
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Thumbprint =(Get-ChildItem -DnsName $FederationName -Path cert:\LocalMachine\My).Thumbprint
    
    Node localhost
    {
        WindowsFeature RSAT
        {
             Ensure = "Present"
             Name = "RSAT"
             IncludeAllSubFeature = $true
        }
        
        WindowsFeature WebApplicationProxy
        {
            Ensure = "Present"
            Name = "Web-Application-Proxy"
            IncludeAllSubFeature = $true
        }

        cADFSWebApplicationProxy WebApplicationProxyApp
        {
            Ensure = "Present"
            Name = $WebApplicationProxyName
            FederationName = $FederationName
            CertificateThumbprint = $Thumbprint
            ServiceCredential = $DomainCreds
            ExternalPreAuthentication = "PassThrough";
            DependsOn = "[WindowsFeature]WebApplicationProxy"
        }

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[cADFSWebApplicationProxy]WebApplicationProxyApp"
        }
    }
}