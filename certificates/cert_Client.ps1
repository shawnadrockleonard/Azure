<# 
.NAME
    Grab certificates and create the config file for the [clients] and [servers]

.AUTHOR
	Shawn Leonard (MSFT Engineer)

.EULA

    Microsoft provides programming examples for illustration only, without 
    warranty either expressed or implied, including, but not limited to, the
    implied warranties of merchantability and/or fitness for a particular 
    purpose.  

    This sample assumes that you are familiar with the programming language
    being demonstrated and the tools used to create and debug procedures. 
    Microsoft support professionals can help explain the functionality of a
    particular procedure, but they will not modify these examples to provide
    added functionality or construct procedures to meet your specific needs. 
    If you have limited programming  experience, you may want to contact a 
    Microsoft Certified Partner or the Microsoft fee-based consulting line 
    at (800) 936-5200. 

.REMARKS
    Will take a cert out of the cert store and grab its base64 encoding for IIS mapping

.SAMPLE

# Run this on a server by server basis
    .\certificates\cert_Client.ps1 -FriendlyName "csp.shawniq.com" `
        -ClientCertificateXmlFilename "L:\temp\client-cert.xml" `
        -ClientConfigFile "L:\temp\client-sample.config" `
        -ServerConfigFile "L:\temp\server-sample.config" -Verbose
#>
[cmdletbinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$FriendlyName,  

    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true)]
    [string]$ClientCertificateXmlFilename,

    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true)]
    [string]$ClientConfigFile,

    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true)]
    [string]$ServerConfigFile
)
begin
{

    
    Import-Module .\module\CACert.Module -Force -Verbose:$false


    # Global Variables
    $script:identity = Get-CurrentIdentity -Verbose:$VerbosePreference


    # Local Variables


    # Establish the running directories
    $outputDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if (!(Test-Path -Path $scriptDirectory -PathType 'Container' -ErrorAction SilentlyContinue))
    {
        $scriptDirectory = (New-Item -Path $outputDirectory -ItemType Directory -Force).FullName
    }

    $certPath = Join-Path -Path $scriptDirectory -ChildPath "issued-certs"
    if (!(Test-Path -Path $certPath -PathType 'Container' -ErrorAction SilentlyContinue))
    {
        $certPath = (New-Item -Path $certPath -ItemType Directory -Force).FullName
    }
}
PROCESS
{

    
    Write-Verbose ("Reading [Client] Certificate XML contents of {0} into memory" -f $ClientCertificateXmlFilename)
    $certConfig = [xml](Get-Content -Path $ClientCertificateXmlFilename)
    $friendlyNameNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='friendlyName']")
    if (!($friendlyNameNode.IsEmpty) -and $friendlyNameNode.InnerText -ne $FriendlyName)
    {
        Write-Warning "The friendly name provided in the parameter does not match the friendly name in the XML file"
        return
    }

    
    $serialNoNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='serialNumber']")
    $serialNo = $serialNoNode.InnerText
    $base64Node = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='base64']")
    $base64RAW = $base64Node.InnerText
    Write-Verbose ("Found {0} serial number in the file {1}" -f $serialNo, $ClientCertificateXmlFilename)


    if ($serialNo.Length -le 1 -or $base64RAW.Length -le 1)
    {
        Write-Warning ("No serial number or base64 is populated in the file {0}" -f $ServerCertificateXmlFilename)
    }
    else
    {


        # Export the Cert to disk
        $base64cer = Get-ChildItem -path Cert:\LocalMachine\My | Where-Object { $Null -ne $_.SerialNumber -and $_.SerialNumber -eq $serialNo } | Sort-Object -Property NotBefore -Descending
        $base64CertificateCount = ($base64cer | Measure-Object).Count
        if ($null -eq $base64cer -or ($base64CertificateCount -le 0))
        {
            Write-Warning ("Could not find a certificate in the LocalMachine\My store for SerialNo:{0}" -f $serialNo)
            Write-Warning ("Ensure you have run the Generate/Complete/Export/Import commands before proceeding......")
        }
        else
        {   
        
            if ($base64CertificateCount -gt 1)
            {
                Write-Warning ("Found more than one certificate in the store.....")
                Write-Warning ("The process should emit multiple files per the serial numbers")
            }


            Write-Verbose ("Reading web config contents of {0} into memory" -f $ClientConfigFile)

            $doc = (Get-Content $ClientConfigFile) -as [Xml]
            $behavior = $doc.configuration.'system.serviceModel'.behaviors.endpointBehaviors.behavior | Where-Object { $_.name -eq "ohBehave" }
            $behavior.clientCredentials.clientCertificate.findValue = [string]$serialNo

            $clientCertAppSetting = $doc.configuration.appSettings.add | where-object { $_.key -eq "clientCert" }
            $clientCertAppSetting.value = [string]$serialNo

            $clientFile = (Get-Item -Path $ClientConfigFile)
            $clientConfigFilename = $clientFile.Name.Replace($clientFile.Extension, "-revised.config")
            $clientNameConfigFile = Join-Path -Path $certPath -ChildPath $clientConfigFilename
            Write-Verbose ("Updated webconfig and saving to {0}" -f $clientNameConfigFile)
            $doc.Save($clientNameConfigFile)    



        
            Write-Verbose ("Prompting for username and password of IIS mapped user")
            $userName = Read-Host "Provide the username (EX: user@domain.com)"
            $userPassword = Read-Host ("Provide the password for the user {0} which will be mapped in IIS" -f $userName) -AsSecureString
            $iisCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $userPassword




            Write-Verbose ("Reading contents of {0} into memory" -f $ServerConfigFile)
            $serverdoc = (Get-Content $ServerConfigFile) -as [Xml]
            $mapping = $serverdoc.configuration.'system.webServer'.security.authentication.iisClientCertificateMappingAuthentication.oneToOneMappings.add
            $mapping.userName = $iisCreds.UserName
            $mapping.password = ($iisCreds.GetNetworkCredential()).Password
            $mapping.certificate = [string]$base64RAW
            
            $serverFile = (Get-Item -Path $ServerConfigFile)
            $serverConfigFilename = $serverFile.Name.Replace($serverFile.Extension, "-revised.config")
            $serverNameConfigFile = Join-Path -Path $certPath -ChildPath $serverConfigFilename
            Write-Verbose ("Updated webconfig and saving to {0}" -f $serverNameConfigFile)
            $serverdoc.Save($serverNameConfigFile)   

        }
    }
}