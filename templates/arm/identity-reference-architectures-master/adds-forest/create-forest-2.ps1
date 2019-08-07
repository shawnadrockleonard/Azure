# $DomainName         -  FQDN for the Active Directory Domain to create
# $DomainNetbiosName  -  AD domain netbios name
# $AdminCreds         -  a PSCredentials object that contains username and password 
#                        that will be assigned to the Domain Administrator account
# $SafeModeAdminCreds -  a PSCredentials object that contains the password that will
#                        be assigned to the Safe Mode Administrator account
# $TargetDomainName   -  Domain Name to establish the Trust
# $ForwardIpAddress   -  IP Addresses used for set the conditional forward zone
#                        for the trust relationship
# $RetryCount         -  defines how many retries should be performed while waiting
#                        for the domain to be provisioned
# $RetryIntervalSec   -  defines the seconds between each retry to check if the 
#                        domain has been provisioned 
Configuration CreateForest {
    param
    #v1.4
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SafeModeAdminCreds,

        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$DomainNetbiosName,

        [Parameter(Mandatory)]
        [string]$TargetDomainName,
        
        [Parameter(Mandatory)]
        [string]$ForwardIpAddress,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xStorage, xActiveDirectory, xNetworking, xPendingReboot

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminCreds.Password)
    [System.Management.Automation.PSCredential ]$SafeDomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SafeModeAdminCreds.UserName)", $SafeModeAdminCreds.Password)

    $Interface = Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    
    Node localhost
    {
        LocalConfigurationManager
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        } 

        xWaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec = 60
            RetryCount = 20
        }
        
        xDisk FVolume
        {
            DiskId = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
            FSFormat = 'NTFS'
            DependsOn = '[xWaitForDisk]Disk2'
        }        

        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSAT
        {
             Ensure = "Present"
             Name = "RSAT"
        }        

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
        }  

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        xADDomain AddDomain
        {
            DomainName = $DomainName
            DomainNetbiosName = $DomainNetbiosName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        xWaitForADDomain DomainWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            RebootRetryCount = 5
            DependsOn = "[xADDomain]AddDomain"
        } 

        xADDomainController PrimaryDC 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = "[xWaitForADDomain]DomainWait"
        }

        Script SetConditionalForwardedZone {
            GetScript = {return @{}}

            TestScript = {
                $zone = Get-DnsServerZone -Name $using:TargetDomainName -ErrorAction SilentlyContinue
                if($zone -ne $null -and $zone.ZoneType -eq 'Forwarder'){
                    return $true
                }

                return $false
            }

            SetScript = {
                $ForwardDomainName = $using:TargetDomainName
                $ForwardAddress = $using:ForwardIpAddress
                $IpAddresses = @()
                foreach($address in $ForwardAddress.Split(',')){
                    $IpAddresses += [IPAddress]$address.Trim()
                }
                Add-DnsServerConditionalForwarderZone -Name "$ForwardDomainName" -ReplicationScope "Domain" -MasterServers $IpAddresses
            }
        }

        xADDomainTrust SetOutboundDomainTrust {
            Ensure = 'Present'
            SourceDomainName = $DomainName
            TargetDomainName = $TargetDomainName
            TargetDomainAdministratorCredential = $AdminCreds
            TrustType = 'External'
            TrustDirection = 'Outbound'
            PsDscRunAsCredential = $AdminCreds
            DependsOn = "[xADDomainController]PrimaryDC"
        }
        
        # xADDomainTrust SetInboundDomainTrust {
        #     Ensure = 'Present'
        #     SourceDomainName = $TargetDomainName
        #     TargetDomainName = $DomainName
        #     TargetDomainAdministratorCredential = $AdminCreds
        #     TrustType = 'External'
        #     TrustDirection = 'Inbound'
        #     PsDscRunAsCredential = $AdminCreds
        #     DependsOn = "[xADDomainController]PrimaryDC"
        # }
        
        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xADDomainController]PrimaryDC"
        }
   }
}