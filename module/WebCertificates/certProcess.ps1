<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    Build Certificates based on the GUI requests
    Complete various tasks related to processing and exporting the requisite files

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

.SAMPLE
    
# Will generate the REQ file for the Certificate authority
    .\certProcess.ps1 -FriendlyName "wcf.shawniq.com" -GenerateREQ -infFilename L:\temp\san-server-wcfshawniqcom.inf -Verbose  

# Will deploy the REQ file to the Certificate Authority
    .\certProcess.ps1 -FriendlyName "csp-server-cert" -GenerateCER -reqFilename "L:\temp\server-wcfshawniqcom.req" -Verbose
    .\certProcess.ps1 -FriendlyName "csp-server-cert" -GenerateCER -reqFilename "L:\temp\server-wcfshawniqcom.req" -CertAuthorityFullName "ca-fqdn\caname" -Verbose

# Will complete the CER from the Certificate Authority or the .base64 cer file from a CA and install in the LocalMachine\My
# Will update the XML file for storage
    .\certProcess.ps1 -FriendlyName "csp.shawniq.com" -CompleteCER -base64certfile "L:\temp\san-server-cspshawniqcom.cer" -Verbose

# Will export the Base64, CER, PFX, and XML files
	.\certProcess.ps1 -FriendlyName "csp.shawniq.com" -Export -pfxXmlFile L:\temp\san-clws-client-base64.xml -Verbose

# Will import the PFX into remote stores
	.\certProcess.ps1 -FriendlyName "csp.shawniq.com" -Import -pfxXmlFile L:\temp\san-clws-client-base64.xml -Verbose



#>
[cmdletbinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$FriendlyName,
    
    
    #region begin Run the PS-Session to evaluate Import options
    [Parameter(Mandatory = $false, ParameterSetName = 'TestWinRM')]
    [switch]$ValidatePSSession,
    [parameter(Mandatory = $False, ParameterSetName = 'TestWinRM')]
    [string[]]$ValidateComputers = $env:COMPUTERNAME,
    #endregion
    
    
    #region begin Create the REQ file from the INF file
    [Parameter(Mandatory = $false, ParameterSetName = 'createreq')]
    [switch]$GenerateREQ,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true, ParameterSetName = 'createreq')]
    [string]$infFilename,
    #endregion
    
    
    #region begin GenerateCER Dev/Test purposes will enable you to create a .cer file from the Certificate Authority
    [Parameter(Mandatory = $false, ParameterSetName = 'caadmin')]
    [switch]$GenerateCER,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true, ParameterSetName = 'caadmin')]
    [string]$reqFilename,
    [Parameter(Mandatory = $false, ParameterSetName = 'caadmin')]
    [string]$CertAuthorityFullName,
    #endregion


    #region begin CompleteCER used to accept the CER file from the Certificate Authority will generate a CER file
    [Parameter(Mandatory = $false, ParameterSetName = 'completecert')]
    [switch]$CompleteCER,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $false, ParameterSetName = 'completecert')]
    [string]$base64certfile,
    #endregion

    #region begin Export PFX from Certificate store
    [Parameter(Mandatory = $false, ParameterSetName = 'Export')]
    [switch]$Export,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true, ParameterSetName = 'Export')]
    [string]$pfxXmlFile,
    #endregion
    
    
    #regin begin Run the CER import process
    [Parameter(Mandatory = $false, ParameterSetName = 'InstallCert')]
    [switch]$InstallCert,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true, ParameterSetName = 'InstallCert')]
    [string]$CERFilename,
    [parameter(Mandatory = $False, ParameterSetName = 'InstallCert')]
    [string[]]$ClientComputers = $env:COMPUTERNAME,
    #endregion
    

    #regin begin Run the PFX import process
    [Parameter(Mandatory = $false, ParameterSetName = 'Import')]
    [switch]$Import,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [Parameter(Mandatory = $true, ParameterSetName = 'Import')]
    [string]$PFXFilename,
    [parameter(Mandatory = $False, ParameterSetName = 'Import')]
    [string[]]$RemoteComputers = $env:COMPUTERNAME
    #endregion
)
BEGIN {

    
    Import-Module .\CACert.Module -Force -Verbose:$false


    # Global Variables
    $script:certfilename = ""
    $script:xmlfilename = ""
    $script:CAuthority = ""
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


    #region begin Validate WinRM
    
    if ($ValidatePSSession) {

        Write-Verbose ("Validating WinRM for Computers at {0}" -f (Get-Date))

        Write-Verbose ("You must enter your credentials to proceed with deploying")
        $CredPassword = ConvertTo-SecureString -String "Super`$Welcome1" -AsPlainText -force
        $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList "shawniq\epaadmin", $CredPassword
        $psCredentials = Get-Credential -Credential $Credentials
    
        ForEach ($Computer in $ValidateComputers) {
        
            if ($Computer -eq $env:COMPUTERNAME) {
                Write-Verbose ("The computer {0} is the current computer, no PSSession required" -f $Computer)
            }
            else {
                Try {
                    Write-Verbose ("Testing Enable-PSSession on {0}" -f $Computer)
                    $session = New-PSSession -ComputerName $Computer -Credential $psCredentials -Verbose:$VerbosePreference
                    Write-Verbose ("Session {0}" -f $session.Id)
                }
                Catch {
                    Write-Warning  "$($Computer): $_"
                }
                finally {
                    if ($null -ne $session) {
                        Remove-PSSession -Session $session -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
                    }
                }
            }
        }    
    }
    
    #endregion Validate WinRM


    #region begin GenerateREQuest

    if ($GenerateREQ) {

        # Generate the REQ file from the INF
        Write-Verbose -Message ("Generating the REQ file from {0}" -f $infFilename)
        $reqfile = $infFilename.Replace(".inf", ".req")

        # Generate the Base64 encoding of the request
        Write-Verbose "----------------"
        Write-Verbose ("Generating the REQ {0} file" -f $reqfile)
        Write-Verbose "----------------"

        certreq.exe -new $infFilename $reqfile 
        Write-Warning -Message ("The REQ file was generated at {0}" -f $reqfile)
        Write-Verbose -Message "Generated Request, take your .req file to your Certificate Authority for completion"
        Write-Verbose -Message ""
        Write-Verbose -Message ("If you want to validate the Request open {0} and copy the contents into https://cryptoreport.websecurity.symantec.com/checker/views/csrCheck.jsp" -f $reqFile)
        Write-Verbose -Message ("If this is Dev/Test or you can submit to your internal CA;")
        Write-Warning -Message ("Use this command:")
        Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -GenerateCER -reqFilename ""{1}""  -Verbose" -f $FriendlyName, $reqfile)
        Write-Verbose -Message ""
        Write-Verbose -Message "If this is not Dev/Test and you have received a .CER file from your Certificate Authority;"
        Write-Warning -Message ("Use this command:")
        Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -CompleteCER -base64CertFile ""{1}""  -Verbose" -f $FriendlyName, $reqfile.Replace(".req", ".cer"))
    }

    #endregion GenerateREQuest


    # this is only available if Dev/Test and you've configured a Certificate Authority that is Windows Based
    if ($GenerateCER) {

        
        if ($null -eq $CertAuthorityFullName -or $CertAuthorityFullName.length -le 1) {
            Write-Warning ("You have not specified a Certificate Authority.")
            $script:CAuthority = Get-CertificateAuthorities -Verbose:$VerbosePreference

            @($script:CAuthority) | ForEach-Object {
                $caLocal = $_
                Write-Warning -Message ("Use this command:")
                Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -GenerateCER -CertAuthorityFullName ""{1}"" -reqFilename ""{2}"" -Verbose" -f $FriendlyName, $caLocal, $reqFilename)

                $ca = certutil -catemplates -config  $caLocal
                $ca | ForEach-Object { 
                    Write-Verbose ("CA Template {0}" -f $_)  
                }
            }
        }
        else {
            Write-Verbose ("Evaluating the REQ in the CSR validation utility")
            # Evaluate the request
            # also launch https://cryptoreport.websecurity.symantec.com/checker/views/csrCheck.jsp
            certutil $reqFilename


            Write-Verbose "Querying the [My] certificate store"
            # Display Certs from (Local Commputer) Personal/Certs
            $certificates = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $Null -ne $_.FriendlyName -and $_.FriendlyName -eq $FriendlyName } | Sort-Object -Property NotBefore -Descending 
            if ($null -ne $certificates -and ($certificates | Measure-Object).Count -gt 0) {
                Write-Warning ("The LocalMachine\My Certificate store contains an existing certificate with friendly name {0}" -f $FriendlyName)
            }
            else {

                $localcerFileName = $reqFileName.Replace(".req", ".cer")
                Write-Verbose ("Will submit .req and result into {0}" -f $cerFileName)

                # Submit to CA for issuance
                certreq.exe -submit -config $CertAuthorityFullName $reqFileName $localcerFileName

                Write-Verbose ("Successfully submitted {0} to the CA" -f $reqFilename)
                Write-Warning ("Use this command:")
                Write-Warning (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -CompleteCER -base64CertFile ""{1}""  -Verbose" -f $FriendlyName, $localcerFileName)
            }
        }
    }


    #region begin CompleteBase64

    if ($CompleteCER) {

        Write-Verbose "Now accepting the base 64 certificate on the creating machine"
        
        #The –accept parameter links the previously generated private key with the issued certificate and 
        #removes the pending certificate request from the system where the certificate is requested (if there is a matching request).   
        try {                
            Write-Verbose "This will install the certificate under LocalMachine\My"
            certreq.exe -accept $base64certfile
        }
        catch {
            Write-Error $Error[0]
        }
        
        $certificatesInStore = Get-ChildItem -path Cert:\LocalMachine\My | Where-Object { $Null -ne $_.FriendlyName -and $_.FriendlyName -eq $FriendlyName } | 
        Sort-Object -Property NotBefore -Descending | 
        Select-Object -Property FriendlyName, Subject, SerialNumber, NotBefore
            
        $foundInStore = ($certificatesInStore | Measure-Object).Count
        if ($null -eq $certificatesInStore -or $foundInStore -le 0) {
            Write-Error ("The process could not find certificates matching friendly name {0}" -f $FriendlyName)
            Write-Error ("Make sure you are running this command on the computer that created the request.......")
        }
        else {
            if ($foundInStore -gt 1) {
                Write-Warning ("Found more than one certificate in the store.....")
                Write-Warning ("The XML file should emit multiple files per the serial numbers")
            }

            $certificatesInStore | ForEach-Object {
                Write-Verbose -Message ("The following => Subject [{0}]; SerialNo [{1}]; NotBefore [{2}]" -f $_.Subject, $_.SerialNumber, $_.NotBefore)
            }
            
            $file = get-item -Path $base64certfile
            Write-Warning -Message ("Use this command:")
            Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -Export -pfxXmlFile ""{1}""  -Verbose" -f $FriendlyName, $base64certfile.Replace($file.Extension, ".xml"))
        }
    }

    #endregion CompleteBase64




    #region begin Export

    if ($Export) {

        $certConfig = [xml](Get-Content -Path $pfxXmlFile)
        $friendlyNameNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='friendlyName']")
        if (!($friendlyNameNode.IsEmpty) -and $friendlyNameNode.InnerText -ne $FriendlyName) {
            Write-Warning "The friendly name provided in the parameter does not match the friendly name in the XML file"
            return
        }
        
        # Export the Cert to disk
        $base64cer = Get-ChildItem -path Cert:\LocalMachine\My | Where-Object { $Null -ne $_.FriendlyName -and $_.FriendlyName -eq $FriendlyName } | Sort-Object -Property NotBefore -Descending
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


            $serialNo = $base64cer.SerialNumber
            $base64String = [System.Convert]::ToBase64String($base64cer.RawData, 'InsertLineBreaks')
        
            $localpfxFileName = $pfxXmlFile.Replace(".xml", ".pfx")
            $crtjoined = $pfxXmlFile.Replace(".xml", ".crt")
            $base64joined = $pfxXmlFile.Replace(".xml", ".base64")


            Write-Verbose ("PFX File {0} will be the target for exporting" -f $localpfxFileName)
            If (Test-Path -Path $localpfxFileName -PathType leaf) {
                Write-Warning ("{0} File Exists, now removing" -f $localpfxFileName)
                Remove-Item -Path $localpfxFileName -Force
            }
        
            Write-Warning "Will prompt user for password for the exported PFX file"
            
            $SecurePassword = Read-Host -Prompt "Enter the PFX password" -AsSecureString
            if ($SecurePassword.Length -le 1) {
                Write-Error -Message "You must provide a password to continue"
                exit;
            }

            $UserName = $script:identity.Name
            $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
            $PlainPassword = $Credentials.GetNetworkCredential().Password


            certutil -exportPFX -p $PlainPassword my $serialNo $localpfxFileName
        

            If (Test-Path -Path $crtjoined -PathType leaf) {
                Write-Warning ("{0} File Exists, now removing" -f $crtjoined)
                Remove-Item -Path $crtjoined -Force
            }
            $content = @(
                '-----BEGIN CERTIFICATE-----'
                $base64String
                '-----END CERTIFICATE-----'
            )
            $content | Out-File -FilePath $crtjoined -Encoding ascii
    

            "" | Out-File $base64joined -Force
            $base64txt = (Get-Content $crtjoined ) 
            $arraybase64 = $base64txt -split "\n"
            $base64SingleLineText = (($arraybase64 | Where-Object { $_ -notmatch "CERTIFICATE" }) -join '').trim()
            [System.IO.File]::WriteAllText($base64joined, $base64SingleLineText, [System.Text.Encoding]::ASCII)
        
            Write-Verbose ("Writing values to the XML file {0}" -f $pfxXmlFile)
            $serialNoNode = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='serialNumber']")
            $serialNoNode.InnerText = $serialNo
            $base64Node = $certConfig.SelectSingleNode("/Objects/Object/Property[@Name='base64']")
            $base64Node.InnerText = $base64SingleLineText
        
            $certConfig.Save($pfxXmlFile)

            
            $file = get-item -Path $pfxXmlFile
            Write-Warning -Message "Use this command to Install the PFX certificates:"
            Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -Import -PFXFilename ""{1}"" -RemoteComputers @(""SRV01"",""SRV02"") -Verbose" -f $FriendlyName, $localpfxFileName)
            Write-Verbose -Message ""
            Write-Warning -Message "Use this command to Install the Client Auth certificates:"
            Write-Warning -Message (">>> .\certProcess.ps1 -FriendlyName ""{0}"" -InstallCert -CERFilename ""{1}"" -ClientComputers @(""SRV01"",""SRV02"") -Verbose" -f $FriendlyName, $crtjoined)
            
        }
    }

    #endregion Export


    #region begin AddTrustedPeople Client Authentication
    
    
    if ($InstallCert) {
        # Need to install the base64 into the Current User\Trusted People
        Write-Verbose ("Starting process to install cert {0} to {1} number of servers" -f $CERFilename, ($ClientComputers | Measure-Object).Count)

        Write-Verbose ("You must enter your credentials to proceed with deploying")
        $psCredentials = Get-Credential -Credential $script:identity.Name

    
        ForEach ($Computer in $ClientComputers) {
        
            $msg = ("Adding certificate {0} to {1}" -f $absolutePfxFilePath, $Computer)
            If ($PSCmdlet.ShouldProcess($msg, "Add|Updating")) {

                if ($Computer -eq $env:COMPUTERNAME) {
                    Install-Certificate -FriendlyName $FriendlyName -CertificateFileName $CERFilename -Computer $Computer -StoreName "TrustedPeople" -StoreLocation "CurrentUser" -Verbose:$verbosepreference
                }
                else {
                    Try {
                        $session = New-PSSession -ComputerName $Computer -Credential $psCredentials -Verbose:$VerbosePreference
                        if ($null -ne $session -and $session.State -eq "Opened") {
                            Install-PSSessionCertificate -Session $session -FriendlyName $FriendlyName -CertificateFileName $CERFilename -StoreName "TrustedPeople" -StoreLocation "CurrentUser" -Verbose:$verbosepreference
                        }
                    }
                    Catch {
                        Write-Warning  "$($Computer): $_"
                    }
                    finally {
                        if ($null -ne $session) {
                            Remove-PSSession -Session $session -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
    }
    
    #endregion


    #region begin AddCertToStore

    if ($Import) {

        # Need to install the base64 into the Local Computer\My
        Write-Verbose ("Starting process to install PFX {0}" -f $PFXFilename)

                    
        #$pfxPassword = ConvertTo-SecureString -String "Password1" -AsPlainText -force
        $pfxPassword = Read-Host -Prompt "Enter the PFX password" -AsSecureString
        if ($pfxPassword.Length -le 1) {
            Write-Error -Message "You must provide a password to continue"
            return;
        }

        Write-Verbose ("You must enter your credentials to proceed with deploying")
        $psCredentials = Get-Credential -Credential $script:identity.Name

    
        ForEach ($Computer in $RemoteComputers) {
        
            $msg = ("Adding certificate {0} to {1}" -f $absolutePfxFilePath, $Computer)
            If ($PSCmdlet.ShouldProcess($msg, "Add|Updating")) {

                if ($Computer -eq $env:COMPUTERNAME) {
                    Install-PFX -FriendlyName $FriendlyName -PFXPassword $pfxPassword -absolutePfxFilePath $PFXFilename -StoreName "My" -StoreLocation "LocalMachine" -Verbose:$verbosepreference
                }
                else {
                    Try {
                        $session = New-PSSession -ComputerName $Computer -Credential $psCredentials -Verbose:$VerbosePreference
                        if ($null -ne $session -and $session.State -eq "Opened") {
                            Install-PSSessionPFX -Session $session -FriendlyName $FriendlyName -PFXPassword $pfxPassword -absolutePfxFilePath $PFXFilename -StoreName "My" -StoreLocation "LocalMachine" -Verbose:$verbosepreference
                        }
                    }
                    Catch {
                        Write-Warning  "$($Computer): $_"
                    }
                    finally {
                        if ($null -ne $session) {
                            Remove-PSSession -Session $session -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
    }

    #endregion AddCertToStore
    
}