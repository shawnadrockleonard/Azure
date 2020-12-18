<# 
.NAME
    Grab certificates and deploy to the server

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
    Please note the PFX file must be located in the same directory as the XML

.SAMPLE

# Run this remotely to all server basis
    .\cert_server.ps1 -FriendlyName "csp.shawniq.com" `
        -WebSiteName "Default Web Site\authOption" `
        -ServerCertificateXmlFilename "l:\temp\server-cert.xml" `
        -ServerConfigFile "l:\temp\config_web-revised.config" `
        -RemoteComputers @("server1","server2") -Verbose

#>
[cmdletbinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$FriendlyName,
  
    [ValidateScript( {Test-Path $_ -PathType Leaf})]
    [Parameter(Mandatory = $true)]
    [string]$ServerCertificateXmlFilename,

    [ValidateScript( {Test-Path $_ -PathType Leaf})]
    [Parameter(Mandatory = $true)]
    [string]$ServerConfigFile,

    [Parameter(Mandatory = $true)]
    [string]$WebSiteName,

    [parameter(Mandatory = $False)]
    [string[]]$RemoteComputers = $env:COMPUTERNAME
)
begin {

    Import-Module .\CACert.Module -Force -Verbose:$false


    # Global Variables
    $script:identity = Get-CurrentIdentity -Verbose:$VerbosePreference


    # Local Variables


    # Establish the running directories
    $outputDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if (!(Test-Path -Path $scriptDirectory -PathType 'Container' -ErrorAction SilentlyContinue)) {
        $scriptDirectory = (New-Item -Path $outputDirectory -ItemType Directory -Force).FullName
    }

    $certPath = Join-Path -Path $scriptDirectory -ChildPath "issued-certs"
    if (!(Test-Path -Path $certPath -PathType 'Container' -ErrorAction SilentlyContinue)) {
        $certPath = (New-Item -Path $certPath -ItemType Directory -Force).FullName
    }

    # Move to running directory
    Set-Location $scriptDirectory

}
PROCESS {



    Write-Verbose ("Reading [Server] Certificate XML contents of {0} into memory" -f $ServerCertificateXmlFilename)
    $certConfig = [xml](Get-Content -Path $ServerCertificateXmlFilename)
    $friendlyNameNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='friendlyName']")
    if (!($friendlyNameNode.IsEmpty) -and $friendlyNameNode.InnerText -ne $FriendlyName) {
        Write-Warning "The friendly name provided in the parameter does not match the friendly name in the XML file"
        return
    }

    # Read the Serial Number so we can pull it from the Store
    $serialNoNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='serialNumber']")
    $serialNo = $serialNoNode.InnerText
    if ($serialNo.Length -le 1) {
        Write-Warning ("No serial number is populated in the file {0}" -f $ServerCertificateXmlFilename)
    }
    else {
        Write-Verbose ("Found {0} serial number in the file {1}" -f $serialNo, $ServerCertificateXmlFilename)
    
        # Export the Cert to disk
        $base64cer = Get-ChildItem -path Cert:\LocalMachine\My | Where-Object { $Null -ne $_.SerialNumber -and $_.SerialNumber -eq $serialNo } | Sort-Object -Property NotBefore -Descending
        $base64CertificateCount = ($base64cer | Measure-Object).Count
        if ($null -eq $base64cer -or ($base64CertificateCount -le 0)) {
            Write-Warning ("Could not find a certificate in the LocalMachine\My store for {0}" -f $FriendlyName)
            Write-Warning ("Ensure you have run the Generate/Complete commands before proceeding......")
        }
        else {   
        
            if ($base64CertificateCount -gt 1) {
                Write-Warning ("Found more than one certificate in the store.....")
                Write-Warning ("The process should emit multiple files per the serial numbers")
            }


            Write-Verbose ("You must enter your credentials to proceed with deploying")
            $userName = Read-Host "Provide the username (EX: user@domain.com) which will be mapped in IIS"
            $userPassword = Read-Host ("Provide the password for the user {0} which will be mapped in IIS" -f $userName) -AsSecureString
            $iisCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $userPassword
    

            Write-Verbose ("You must enter your [Admin] credentials to proceed with deploying")
            $psCredentials = Get-Credential -Credential $script:identity.Name
    
        
            ForEach ($Computer in $RemoteComputers) {
            
                $msg = ("Adding iis configs {0} to {1}" -f $absolutePfxFilePath, $Computer)
                If ($PSCmdlet.ShouldProcess($msg)) {
                    if ($Computer -eq $env:COMPUTERNAME) {
                        Enable-IISOverrides -WebSiteName $WebSiteName -UserAccount $iisCreds -absoluteConfigFilePath $ServerConfigFile -Verbose:$verbosepreference
                    }
                    else {
                        Try {
    
                            $session = New-PSSession -ComputerName $Computer -Credential $psCredentials -Name "iisRemote" -Verbose:$VerbosePreference
                            Enable-PSSessionIISOverrides -Session $session -WebSiteName $WebSiteName -UserAccount $iisCreds -absoluteConfigFilePath $ServerConfigFile -Verbose:$verbosepreference
                        }
                        Catch {
                            Write-Warning  "$($Computer): $_"
                        }
                        finally {
                            Remove-PSSession -Session $session -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
                        }
                    }
                }
            }


        }
    }
}