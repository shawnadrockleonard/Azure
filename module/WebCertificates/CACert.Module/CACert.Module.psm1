function Use-ActiveDirectory {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    BEGIN {
        Write-Verbose "..  Loading AD"
    }
    PROCESS {

        Import-Module ActiveDirectory -Force
    }
    end {
        Write-Verbose ".. AD loaded"
    }
}

function Show-MessageBox { 
    <#
.SYNOPSIS
Supports alert boxes with various button combinations
#>
    [cmdletbinding()]
    Param( 
        [Parameter(Mandatory = $True)][Alias('M')][String]$Msg, 
        [Parameter(Mandatory = $False)][Alias('T')][String]$Title = "", 
        [Parameter(Mandatory = $False)][Alias('OC')][Switch]$OkCancel, 
        [Parameter(Mandatory = $False)][Alias('OCI')][Switch]$AbortRetryIgnore, 
        [Parameter(Mandatory = $False)][Alias('YNC')][Switch]$YesNoCancel, 
        [Parameter(Mandatory = $False)][Alias('YN')][Switch]$YesNo, 
        [Parameter(Mandatory = $False)][Alias('RC')][Switch]$RetryCancel, 
        [Parameter(Mandatory = $False)][Alias('C')][Switch]$Critical, 
        [Parameter(Mandatory = $False)][Alias('Q')][Switch]$Question, 
        [Parameter(Mandatory = $False)][Alias('W')][Switch]$Warning, 
        [Parameter(Mandatory = $False)][Alias('I')][Switch]$Informational
    ) 
    BEGIN {

        #Loads the WinForm Assembly, Out-Null hides the message while loading. 
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null 
    }
    PROCESS {
        #Set Message Box Style 
        IF ($OkCancel) { $Type = 1 } 
        Elseif ($AbortRetryIgnore) { $Type = 2 } 
        Elseif ($YesNoCancel) { $Type = 3 } 
        Elseif ($YesNo) { $Type = 4 } 
        Elseif ($RetryCancel) { $Type = 5 } 
        Else { $Type = 0 } 
   
    
        #Set Message box Icon 
        If ($Critical) { $Icon = 16 } 
        ElseIf ($Question) { $Icon = 32 } 
        Elseif ($Warning) { $Icon = 48 } 
        Elseif ($Informational) { $Icon = 64 } 
        Else { $Icon = 0 }
     
 
        #Display the message with input 
        $Answer = [System.Windows.Forms.MessageBox]::Show($MSG , $TITLE, $Type, $Icon) 
     
        #Return Answer 
        Return $Answer 
    } 
}

function Get-CurrentIdentity {
    [cmdletbinding()]
    PARAM()
    PROCESS {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        Write-Verbose ("The user {0} was found" -f $identity.Name)
        return $identity
    }
}

function Test-IsLocalAdmin {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [System.Security.Principal.WindowsIdentity]$identity,
        [Parameter(Mandatory = $False)]
        [string]$role
    )
    BEGIN {
        Write-Verbose ("Validating identity for current user in role {0}" -f $role)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
        try {
            $principal = new-object System.Security.Principal.WindowsPrincipal($identity)
            if ($role.Length -le 1) {
                $role = ([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            }
            return $principal.IsInRole($role)
        }
        catch {
            Write-Error $error[0]
        }
    }
}
	
function Get-CertificateAuthorities {
    <#
.SYNOPSIS
Provided to Query the Certificate Authority [no other reason]
#>        
    [cmdletbinding()]
    Param ()
    PROCESS {
    
        if ($script:CAuthority.length -le 0) { 
            Write-Verbose ("Polling for certificate authorities.......")
                
            $cas = certutil -dump
            if ($null -eq $cas -or ($cas | Measure-Object).Count -le 1) {
                Write-Warning "No CA could be found!!!"
            }
            else {
                Write-Verbose "Found a CA, here are some suggestions:"
                $server = $cas | where-object { $_ -like '* Server:*' }
                $server = $server.replace("Server:", "").replace("``", "").replace("'", "").trim()
        
                $caname = $cas | where-object { $_ -like '* Sanitized Name:*' }
                $caname = $caname.replace("Sanitized Name:", "").replace("``", "").replace("'", "").trim()
        
                $script:CAuthority = ("{0}\{1}" -f $server, $caname)
                return $script:CAuthority
            }
        }
    }
}	
	
function Install-Certificate {
    <#
.SYNOPSIS
Will install the Certificate into the Specified Location\Store
#>                
    [cmdletbinding()]
    Param (
        [parameter(Mandatory = $True)]
        $Computer,

        [parameter(Mandatory = $True)]
        [string]$FriendlyName,

        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$CertificateFileName,

        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',

        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'LocalMachine'
    )
    BEGIN {
        Add-Type -AssemblyName System.Security
        Write-Verbose ("Installing {0} to Store {1}\{2}" -f $CertificateFileName, $StoreName, $StoreLocation)
    }
    PROCESS {
    
        $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }
        
        $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
        if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
            "" | Out-File -FilePath $logFile -Force
        }  

        $CertificateObject = $null 
        $thumbprint = $null
        try {
            $CertificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificateFileName)
            # Full path of the certificate 
            $thumbprint = $CertificateObject.Thumbprint 
            Write-Output ("Importing Certificate with thumbprint {0}" -f $thumbprint)
            ("Importing Certificate with thumbprint {0}" -f $thumbprint) | Out-File -FilePath $logFile -Append
        }
        catch {
            Write-Warning  "Error: $_"
            return;
        }        

        Try {
            Write-Verbose  ("Connecting to {0}\{1}" -f $targetComputerStore, $StoreLocation)
                    
            $SourceStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $StoreName, $StoreLocation
            $SourceStore.Open('ReadOnly')
            $CertMatchingFriendly = $SourceStore.Certificates | Where-Object  -FilterScript {
                $_.Thumbprint -eq $thumbprint
            }   
            $SourceStore.Close()                 

            if ($null -eq $CertMatchingFriendly -and (($CertMatchingFriendly | Measure-Object).Count) -le 0) {
                $msg = ("Adding certificate {0} to {1}\{2}" -f $CertificateFileName, $targetComputerStore, $StoreLocation)
                $msg | Out-File -FilePath $logFile -Append
                Write-Warning -Message $msg
                $DestinationStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $StoreName, $StoreLocation
                $DestinationStore.Open('ReadWrite')
                $DestinationStore.Add($CertificateObject)
                $DestinationStore.Close()
            }
            else {
                Write-Warning ("Certificate {0} exists in CERT:\{1}" -f $CertificateFileName, $targetComputerStore)
                ("Certificate {0} exists in CERT:\{1}" -f $CertificateFileName, $targetComputerStore) | Out-File -FilePath $logFile -Append
            }
        }
        Catch {
            Write-Warning  "$($Computer): $_"
            "$($Computer): $_" | Out-File -FilePath $logFile -Append
        }
    }
}

function Install-PSSessionCertificate {
    <#
    .SYNOPSIS
    Will install the Certificate into the Remote Computer in the Specified Location\Store
    #>                
    [cmdletbinding()]
    Param (
        [parameter(Mandatory = $True)]
        $session,

        [parameter(Mandatory = $True)]
        [string]$FriendlyName,
    
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$CertificateFileName,
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'LocalMachine'
    )
    BEGIN {
    
        Write-Verbose ("Installing {0} to Store {1}\{2}" -f $CertificateFileName, $StoreName, $StoreLocation)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
    
        # Write file to server
        $computer = $session.ComputerName
        $filename = (Get-Item -Path $CertificateFileName).Name
        
        $tmpDirectory = ("\\{0}\c$\temp" -f $computer)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }
        $fileToCopy = Join-Path -Path $tmpDirectory -ChildPath $filename
        Copy-Item $CertificateFileName -Destination $fileToCopy -Force
        
        Invoke-Command -Session $session -Script {
            param(
                [string]$name,
                [System.Security.Cryptography.X509Certificates.StoreName]$store,
                [System.Security.Cryptography.X509Certificates.StoreLocation]$location,
                [string]$filename
            )
            
            $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
            if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
                $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
            }
            
            $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
            if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
                "" | Out-File -FilePath $logFile -Force
            }
            
            $file = ("c:\temp\{0}" -f $filename)
            Write-Output  ("Connecting to {0}\{1}" -f $store, $location)
            ("Connecting to {0}\{1}" -f $store, $location) | Out-File -FilePath $logFile -Append

            $CertificateObject = $null
            $thumbprint = $null
            try {
                Write-Output ("Creating object {0}" -f $file)
                ("Creating object {0}" -f $file) | Out-File -FilePath $logFile -Append
                $CertificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($file) -ErrorAction Stop
          
                # Full path of the certificate 
                $thumbprint = $CertificateObject.Thumbprint 
                Write-Output ("Importing Certificate with thumbprint {0}" -f $thumbprint)
                ("Importing Certificate with thumbprint {0}" -f $thumbprint) | Out-File -FilePath $logFile -Append
            }
            catch {
                Write-Warning  "Error: $_"
                "Error: $_" | Out-File -FilePath $logFile -Append
                return;
            }
        
                
            $SourceStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $store, $location
            $SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::'ReadOnly')
        
            $CertMatchingFriendly = $SourceStore.Certificates | Where-Object  -FilterScript {
                $_.Thumbprint -eq $thumbprint
            }   
            "--FriendlyMatching--" | Out-File -FilePath $logFile -Append
            $CertMatchingFriendly | Format-Table -Property * | Out-File -FilePath $logFile -Append

            if ($null -eq $CertMatchingFriendly -and (($CertMatchingFriendly | Measure-Object).Count) -le 0) {
                Write-Output ("Installing {0} in Store {1} Location {2}" -f $file, $store, $location)
                ("Installing {0} in Store {1} Location {2}" -f $file, $store, $location) | Out-File -FilePath $logFile -Append
                $DestinationStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $store, $location
                $DestinationStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                $DestinationStore.Add($CertificateObject)
                $DestinationStore.Close()
            }
            else {
                Write-Warning ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $store, $location)
                ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $store, $location) | Out-File -FilePath $logFile -Append
            }    
            $SourceStore.Close()    
            
        } -ArgumentList $FriendlyName, $StoreName, $StoreLocation, $filename -Verbose:$verbosepreference
    }
}

function Install-PFX {
    <#
    .SYNOPSIS
    Will install the Certificate into the Specified Location\Store
    #>                
    [cmdletbinding()]
    Param (
        [parameter(Mandatory = $True)]
        [string]$FriendlyName,

        [parameter(Mandatory = $False)]
        [string]$computer = $env:COMPUTERNAME,
        
        [Parameter(Mandatory = $True)]
        [Security.SecureString]$PFXPassword,
    
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$absolutePfxFilePath,
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'LocalMachine'
    )
    BEGIN {
    
        Write-Verbose ("Installing {0} to Store {1}\{2}" -f $absolutePfxFilePath, $StoreName, $StoreLocation)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
    
        # Write file to server
        $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }

        $filename = (Get-Item -Path $absolutePfxFilePath).Name
        $file = ("{0}\{1}" -f $tmpDirectory, $filename)
        Copy-Item $absolutePfxFilePath -Destination $file -Force
            
            
        $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
        if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
            "" | Out-File -FilePath $logFile -Force
        }          
            

        $certPassword = (New-Object System.Management.Automation.PSCredential -ArgumentList "user", $PFXPassword).GetNetworkCredential().Password
            

        Write-Output  ("Connecting to {0}\{1}" -f $StoreName, $StoreLocation)
        ("Connecting to {0}\{1}" -f $StoreName, $StoreLocation) | Out-File -FilePath $logFile -Append
        $CertificateObject = $null
        $thumbprint = $null
        try {
            $keys = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags] "Exportable,MachineKeySet,PersistKeySet"
            Write-Output ("Creating object {0} password {1} keys {2}" -f $file, $certPassword, $keys)
            ("Creating object {0} password {1} keys {2}" -f $file, $certPassword, $keys) | Out-File -FilePath $logFile -Append
            $CertificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($file, $certPassword, $keys) -ErrorAction Stop
          
            # Full path of the certificate 
            $thumbprint = $CertificateObject.Thumbprint 
            Write-Output ("Importing PFX with thumbprint {0}" -f $thumbprint)
            ("Importing PFX with thumbprint {0}" -f $thumbprint) | Out-File -FilePath $logFile -Append
        }
        catch {
            Write-Warning  "Error: $_"
            "Error: $_" | Out-File -FilePath $logFile -Append
            return;
        }
        
                
        $SourceStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $StoreName, $StoreLocation
        $SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::'ReadOnly')
        
        $CertMatchingFriendly = $SourceStore.Certificates | Where-Object  -FilterScript {
            $_.Thumbprint -eq $thumbprint
        }   
        "--FriendlyMatching--" | Out-File -FilePath $logFile -Append
        $CertMatchingFriendly | Format-Table -Property * | Out-File -FilePath $logFile -Append
        $SourceStore.Close()    

        if ($null -eq $CertMatchingFriendly -and (($CertMatchingFriendly | Measure-Object).Count) -le 0) {
            Write-Output ("Installing {0} in Store {1} Location {2}" -f $file, $StoreName, $StoreLocation)
            ("Installing {0} in Store {1} Location {2}" -f $file, $StoreName, $StoreLocation) | Out-File -FilePath $logFile -Append
            $DestinationStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $StoreName, $StoreLocation
            $DestinationStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $DestinationStore.Add($CertificateObject)
            $DestinationStore.Close()
        }
        else {
            Write-Warning ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $StoreName, $StoreLocation)
            ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $StoreName, $StoreLocation) | Out-File -FilePath $logFile -Append
        }    

    }
}

function Install-PSSessionPFX {
    <#
    .SYNOPSIS
    Will install the Certificate into the Specified Location\Store
    #>                
    [cmdletbinding()]
    Param (
        [parameter(Mandatory = $True)]
        $session,

        [parameter(Mandatory = $True)]
        [string]$FriendlyName,
        
        [Parameter(Mandatory = $True)]
        [Security.SecureString]$PFXPassword,
    
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$absolutePfxFilePath,
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',
    
        [parameter(Mandatory = $False)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'LocalMachine'
    )
    BEGIN {
    
        Write-Verbose ("Installing {0} to Store {1}\{2}" -f $absolutePfxFilePath, $StoreName, $StoreLocation)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
    
        # Write file to server
        $computer = $session.ComputerName
        $filename = (Get-Item -Path $absolutePfxFilePath).Name
        
        $tmpDirectory = ("\\{0}\c$\temp" -f $computer)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }
        $fileToCopy = Join-Path -Path $tmpDirectory -ChildPath $filename
        Copy-Item $absolutePfxFilePath -Destination $fileToCopy -Force
        
        Invoke-Command -Session $session -Script {
            param(
                [string]$name,
                [Security.SecureString]$pass,
                [System.Security.Cryptography.X509Certificates.StoreName]$store,
                [System.Security.Cryptography.X509Certificates.StoreLocation]$location,
                [string]$filename
            )
            
            $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
            if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
                $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
            }
            
            $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
            if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
                "" | Out-File -FilePath $logFile -Force
            }
            
            $file = ("c:\temp\{0}" -f $filename)
            $certPassword = (New-Object System.Management.Automation.PSCredential -ArgumentList "user", $pass).GetNetworkCredential().Password
            
            Write-Output  ("Connecting to {0}\{1}" -f $store, $location)
            ("Connecting to {0}\{1}" -f $store, $location) | Out-File -FilePath $logFile -Append
            $CertificateObject = $null
            $thumbprint = $null
            try {
                $keys = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags] "Exportable,MachineKeySet,PersistKeySet"
                Write-Output ("Creating object {0} password {1} keys {2}" -f $file, $certPassword, $keys)
                ("Creating object {0} password {1} keys {2}" -f $file, $certPassword, $keys) | Out-File -FilePath $logFile -Append
                $CertificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($file, $certPassword, $keys) -ErrorAction Stop
          
                # Full path of the certificate 
                $thumbprint = $CertificateObject.Thumbprint 
                Write-Output ("Importing PFX with thumbprint {0}" -f $thumbprint)
                ("Importing PFX with thumbprint {0}" -f $thumbprint) | Out-File -FilePath $logFile -Append
            }
            catch {
                Write-Warning  "Error: $_"
                "Error: $_" | Out-File -FilePath $logFile -Append
                return;
            }
        
                
            $SourceStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $store, $location
            $SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::'ReadOnly')
        
            $CertMatchingFriendly = $SourceStore.Certificates | Where-Object  -FilterScript {
                $_.Thumbprint -eq $thumbprint
            }   
            "--FriendlyMatching--" | Out-File -FilePath $logFile -Append
            $CertMatchingFriendly | Format-Table -Property * | Out-File -FilePath $logFile -Append

            if ($null -eq $CertMatchingFriendly -and (($CertMatchingFriendly | Measure-Object).Count) -le 0) {
                Write-Output ("Installing {0} in Store {1} Location {2}" -f $file, $store, $location)
                ("Installing {0} in Store {1} Location {2}" -f $file, $store, $location) | Out-File -FilePath $logFile -Append
                $DestinationStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $store, $location
                $DestinationStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                $DestinationStore.Add($CertificateObject)
                $DestinationStore.Close()
            }
            else {
                Write-Warning ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $store, $location)
                ("Certificate {0} exists in CERT:\{1}\{2}" -f $file, $store, $location) | Out-File -FilePath $logFile -Append
            }    
            $SourceStore.Close()    
            
        } -ArgumentList $FriendlyName, $PFXPassword, $StoreName, $StoreLocation, $filename -Verbose:$verbosepreference
    }
}

function Enable-IISOverrides {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$WebSiteName,

        [Parameter(Mandatory = $True)]
        [System.Management.Automation.PSCredential]$UserAccount,
    
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$absoluteConfigFilePath
    )
    BEGIN {
    
        Write-Verbose ("Copying {0}" -f $absoluteConfigFilePath)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
    
        # Write file to server
        $computer = $env:COMPUTERNAME
        # Write file to server
        $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }

        $filename = (Get-Item -Path $absoluteConfigFilePath).Name
        $file = ("{0}\{1}" -f $tmpDirectory, $filename)
        Copy-Item $absoluteConfigFilePath -Destination $file -Force


        $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
        if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
            "" | Out-File -FilePath $logFile -Force
        }

        $certPassword = $UserAccount.GetNetworkCredential().Password
            
        Write-Output  ("Connecting Server {0} IIS" -f $computer)
        ("Connecting Server {0} IIS" -f $computer) | Out-File -FilePath $logFile -Append


        $path = ("{0}\system32\inetsrv" -f $env:systemroot)
        Write-Output ("Connected to {0} will shift directories to {1}" -f $env:computername, $path)
        ("Connected to {0} will shift directories to {1}" -f $env:computername, $path) | Out-File -FilePath $logFile -Append
        $contents = (@"
cd {0}
c:
appcmd.exe unlock config /section:system.WebServer/security/access -commit:apphost
appcmd.exe unlock config /section:system.WebServer/security/authentication/anonymousAuthentication -commit:apphost
appcmd.exe unlock config /section:system.WebServer/security/authentication/clientCertificateMappingAuthentication -commit:apphost
appcmd.exe unlock config /section:system.webserver/security/authentication/iisClientCertificateMappingAuthentication -commit:apphost

iisreset /noforce
"@ -f $path)


        $batchOutput = Join-Path -Path $tmpDirectory -ChildPath "iisbatch.cmd"
        Write-Output ("Updated iisbatch.cmd and saving to {0}" -f $batchOutput)
        ("Updated iisbatch.cmd and saving to {0}" -f $batchOutput) | Out-File -FilePath $logFile -Append
        $contents | Out-File -FilePath $batchOutput -Encoding ascii -Verbose
        
        Invoke-Item $batchOutput -Verbose:$VerbosePreference
    }
}

function Enable-PSSessionIISOverrides {
    [cmdletbinding()]
    Param (
        [parameter(Mandatory = $True)]
        $session,

        [Parameter(Mandatory = $true)]
        [string]$WebSiteName,

        [Parameter(Mandatory = $True)]
        [System.Management.Automation.PSCredential]$UserAccount,
    
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [parameter(Mandatory = $True)]
        [string]$absoluteConfigFilePath
    )
    BEGIN {
    
        Write-Verbose ("Copying {0}" -f $absoluteConfigFilePath)
        Add-Type -AssemblyName System.Security
    }
    PROCESS {
    
        # Write file to server
        $computer = $session.ComputerName
        $filename = (Get-Item -Path $absoluteConfigFilePath).Name
        
        $tmpDirectory = ("\\{0}\c$\temp" -f $computer)
        if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
            $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
        }
        $fileToCopy = Join-Path -Path $tmpDirectory -ChildPath $filename
        Copy-Item $absoluteConfigFilePath -Destination $fileToCopy -Force
        
        Invoke-Command -Session $session -Script {
            param(
                [string]$name,
                [System.Management.Automation.PSCredential]$svcaccount,
                [string]$filename
            )

            $tmpDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
            if (!(Test-Path $tmpDirectory -PathType Container -ErrorAction SilentlyContinue)) {
                $tmpDirectory = (New-Item -Path $tmpDirectory -ItemType Directory -Force).FullName
            }
            
            $logFile = ("{0}\certlogging.log" -f $tmpDirectory)
            if (!(Test-Path $logFile -PathType Leaf -ErrorAction SilentlyContinue)) {
                "" | Out-File -FilePath $logFile -Force
            }            
      
            $file = ("c:\temp\{0}" -f $filename)
            $certPassword = $svcaccount.GetNetworkCredential().Password
            
            Write-Output  ("Connecting Server {0} IIS" -f $name)
            ("Connecting Server {0} IIS" -f $name) | Out-File -FilePath $logFile -Append


            $path = ("{0}\system32\inetsrv" -f $env:systemroot)
            Write-Output ("Connected to {0} will shift directories to {1}" -f $env:computername, $path)
            ("Connected to {0} will shift directories to {1}" -f $env:computername, $path) | Out-File -FilePath $logFile -Append
            $contents = (@"
cd {0}
c:
appcmd.exe unlock config /section:system.WebServer/security/access -commit:apphost
appcmd.exe unlock config /section:system.WebServer/security/authentication/anonymousAuthentication -commit:apphost
appcmd.exe unlock config /section:system.WebServer/security/authentication/clientCertificateMappingAuthentication -commit:apphost
appcmd.exe unlock config /section:system.webserver/security/authentication/iisClientCertificateMappingAuthentication -commit:apphost

iisreset /noforce
"@ -f $path)


            $batchOutput = Join-Path -Path $tmpDirectory -ChildPath "iisbatch.cmd"
            Write-Output ("Updated iisbatch.cmd and saving to {0}" -f $batchOutput)
            ("Updated iisbatch.cmd and saving to {0}" -f $batchOutput) | Out-File -FilePath $logFile -Append
            $contents | Out-File -FilePath $batchOutput -Encoding ascii -Verbose
        
            Write-Output ("Invoking iisbatch.cmd at {0}" -f (Get-Date))
            Invoke-Item $batchOutput -Verbose:$VerbosePreference
            
        } -ArgumentList $computer, $UserAccount, $filename -Verbose:$verbosepreference
    }
}