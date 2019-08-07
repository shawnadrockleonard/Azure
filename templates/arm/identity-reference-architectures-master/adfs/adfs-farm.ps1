Configuration InstallADFS 
{ 
   param
    (
        [Parameter(Mandatory)]
        [string]$DomainName,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
        
        [Parameter(Mandatory)]
        [string]$NetBiosDomainName,

        [Parameter(Mandatory)]
        [string]$FederationName,

        [Parameter(Mandatory)]
        [string]$Description,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=50
    )

    #Import the required DSC Resources
    Import-DscResource -Module xActiveDirectory, xPendingReboot, xComputerManagement, cADFS
    
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Thumbprint =(Get-ChildItem -DnsName $FederationName -Path cert:\LocalMachine\My).Thumbprint
    
    Node localhost
    {
        LocalConfigurationManager            
        {            
            ActionAfterReboot = "ContinueConfiguration"            
            ConfigurationMode = "ApplyOnly"            
            RebootNodeIfNeeded = $true            
        }

        xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec
        }
         
        xComputer JoinDomain
        {
            Name          = "localhost" 
            DomainName    = $DomainName
            Credential    = $DomainCreds  # Credential to join to domain
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        Script AfterDomainJoinReboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1
            }
            GetScript = { return @{result = 'result'}}
            DependsOn = "[xComputer]JoinDomain"
        }

        WindowsFeature InstallADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
            IncludeAllSubFeature = $true
            DependsOn = "[Script]AfterDomainJoinReboot"
        }

        WindowsFeature InstallWIF
        {
            Ensure = "Present"
            Name   = "Windows-Identity-Foundation"
            IncludeAllSubFeature = $true
            DependsOn = "[WindowsFeature]InstallADFS"
        }

        Script AfterADFSReboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1
            }
            GetScript = { return @{result = 'result'}}
            DependsOn = "[WindowsFeature]InstallWIF"
        }

        cADFSFarm AddADFSFarm
        {   
            Ensure = "Present"
            ServiceName = $FederationName
            DisplayName = $Description
            CertificateThumbprint = $Thumbprint
            ServiceCredential = $DomainCreds
            InstallCredential = $DomainCreds
            DependsOn = "[Script]AfterADFSReboot"
            PsDscRunAsCredential = $Admincreds
        }

        $ServiceAccountName = $DomainCreds.UserName;

        cADFSDeviceRegistration cADFSDeviceRegistration
        {
            Ensure = "Present"
            DomainName = $DomainName
            ServiceCredential = $DomainCreds
            InstallCredential = $DomainCreds
            ServiceAccountName = $ServiceAccountName
            RegistrationQuota = 10
            MaximumRegistrationInactivityPeriod = 90
            DependsOn = "[cADFSFarm]AddADFSFarm"
            PsDscRunAsCredential = $DomainCreds
        }
    }
}