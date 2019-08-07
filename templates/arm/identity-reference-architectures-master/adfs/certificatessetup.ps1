Configuration Certificates
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xNetworking, xComputerManagement

    Node localhost
    {
        File DirectoryTemp
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $false
            DestinationPath = "C:\TempDSCAssets"
            PsDscRunAsCredential = $AdminCreds
        }

        Script GetCerts
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://raw.githubusercontent.com/mspnp/identity-reference-architectures/master/adfs/adfs-certs.zip" 
                $webClient.DownloadFile($uri, "C:\TempDSCAssets\adfs-certs.zip") 
            } 
            TestScript = { Test-Path "C:\TempDSCAssets\adfs-certs.zip" } 
            GetScript = { @{ Result = (Get-Content "C:\TempDSCAssets\adfs-certs.zip") } } 
            DependsOn = '[File]DirectoryTemp'
            PsDscRunAsCredential = $AdminCreds
        }

        Archive CertZipFile
        {
            Path = 'C:\TempDSCAssets\adfs-certs.zip'
            Destination = 'c:\TempDSCAssets\'
            Ensure = 'Present'
            DependsOn = '[Script]GetCerts'
            PsDscRunAsCredential = $AdminCreds
        }

        Script SetupCerts
        { 
            SetScript = 
            { 
                Import-Certificate -FilePath "C:\TempDSCAssets\MyFakeRootCertificateAuthority.cer" -CertStoreLocation 'Cert:\LocalMachine\Root' -Verbose
                $password = ConvertTo-SecureString 'AweS0me@PW' -AsPlainText -Force
                Import-PfxCertificate -FilePath "C:\TempDSCAssets\adfs.contoso.com.pfx" -CertStoreLocation 'Cert:\LocalMachine\My' -Password $password
            }
            TestScript = { return $false } 
            GetScript = { @{ Result = {} } } 
            DependsOn = '[Archive]CertZipFile'
            PsDscRunAsCredential = $AdminCreds
        }
    }
}