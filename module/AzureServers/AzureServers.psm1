
function Remove-NodeModules {
  <#
    .SYNOPSIS
    This will remove the node_modules folder
    
    .DESCRIPTION
    This will remove the node_modules folder
    
    .PARAMETER Path
    The fully qualified path to the source location.
    
    .EXAMPLE
    Remove-NodeModules -Path c:\source\repos
    
    .NOTES
    rimraf needs to be installed globally
    #>
    
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $FALSE)]
    [string]$Path = (Get-Location)
  )
  PROCESS {
    $nodemod = Get-ChildItem -Path $Path -Filter "*node_modules*" -Recurse -Depth 20
    $nodemod | ForEach-Object {
      rimraf $_.FullName
    }
  }
}
  
function Repair-SqlWmi {
  <#
    .SYNOPSIS
    Repairs WMI when agent/service is in crashed state
    
    .DESCRIPTION
    Repairs WMI when agent/service is in crashed state
    
    .EXAMPLE
    Repair-SqlWmi -Verbose
    #>
  [CmdletBinding()]
  Param(
  )
  PROCESS {
  
    Set-Location 'C:\Program Files (x86)\Microsoft SQL Server'
    $sqlproviders = Get-ChildItem -Filter "*sqlmgmproviderxpsp2up*" -Recurse
  
    if ($null -ne $sqlproviders -and ($sqlproviders | Measure-Object).Count -gt 0) {
  
      ForEach ($sqlprovider in $sqlproviders) {
  
        Set-Location $sqlprovider.Directory.FullName
  
        Invoke-Command -ScriptBlock { mofcomp.exe sqlmgmproviderxpsp2up.mof }
      }
    }
  }
}
  
function Register-SqlAlias {
  <#
    .SYNOPSIS
    Create a CLI Config entries for Database alias
    
    .DESCRIPTION
    Create a CLI Config entries for Database alias
    
    .PARAMETER DBServerAlias
    The shortname alias
    
    .PARAMETER DBServer
    The fully qualified server name
    
    .PARAMETER DBServerPort
    The port for TCP connectivity
    
    .EXAMPLE
    Register-SqlAlias -DBServerAlias "TfsDb" -DBServer "SQL-004.fqdn" -DBServerPort 1433
    
    .NOTES
    General notes
    #>
    
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)]
    [string]$DBServerAlias,
  
    [Parameter(Mandatory = $true)]
    [string]$DBServer,
      
    [Parameter(Mandatory = $true)]
    [int]$DBServerPort
  )
  PROCESS {
  
    Write-Verbose ("*** Setting Alias={0}" -f $DBServerAlias)
    Write-Verbose ("*** Setting SQLInstance={0}" -f $DBServer)
  
  
    Write-Verbose "*** Changing Registry for 32 bit"
    $regAlias = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBServerAlias -ErrorAction:SilentlyContinue
    if ($null -eq $regAlias) {
      New-ItemProperty -PropertyType REG_SZ -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBServerAlias `
        -Value ("DBMSSOCN,{0},{1}" -f $DBServer, $DBServerPort)
    }
    
    Write-Verbose "*** Changing Registry for 64 bit"
    $architecture = get-childitem Env:\PROCESSOR_ARCHITECTURE
    $regAlias = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBServerAlias -ErrorAction:SilentlyContinue
    if ($architecture.Value -ne "X86" -and $null -eq $regAlias) { 
      New-ItemProperty -PropertyType REG_SZ -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBServerAlias `
        -Value ("DBMSSOCN,{0},{1}" -f $DBServer, $DBServerPort)        
    }
  }
  END {
    Write-Verbose "*** Script Complete"
  }
}


function Get-NetBIOSName {
  [OutputType([string])]
  param(
    [string]$DomainFQDN
  )

  if ($DomainFQDN.Contains('.')) {
    $length = $DomainFQDN.IndexOf('.')
    if ( $length -ge 16) {
      $length = 15
    }
    return $DomainFQDN.Substring(0, $length)
  }
  else {
    if ($DomainFQDN.Length -gt 15) {
      return $DomainFQDN.Substring(0, 15)
    }
    else {
      return $DomainFQDN
    }
  }
}
function Get-NetBIOSForest {
  [OutputType([string])]
  param(
    [string]$DomainFQDN
  )
  PROCESS {
    $netbios = ("{0}." -f (Get-NetBIOSName -DomainFQDN $DomainFQDN))
    $pureSuffix = $DomainFQDN -replace $netbios, ""
    return $pureSuffix
  }
}
function Get-NetBIOSSuffix {
  [OutputType([string])]
  param(
    [string]$DomainFQDN
  )

  if ($DomainFQDN.Contains('.')) {
    $length = $DomainFQDN.LastIndexOf('.')
    $lastIndex = $DomainFQDN.Length - $length
    if (!( $lastIndex -le 0)) {
      return $DomainFQDN.Substring($length + 1, $lastIndex - 1)   
    }
  }
}
  
function Unprotect-GMSAAccountPassword {
  [CmdletBinding()]
  Param(
    #This defines the account and domain.
    [Parameter(Mandatory = $true, HelpMessage = "The domain, ex: devdc\")]
    [string]$Domain,
    
    #This defines the account and domain.
    [Parameter(Mandatory = $true, HelpMessage = "The managed service account, ex: gsmadfssvc$")]
    [string]$GMSAAccountName,
    
    #This defines the samaccountname of an existing AD account that we can query to make sure the GMSA password decoded correctly.
    [Parameter(Mandatory = $true, HelpMessage = "The test ad account, ex: sleon")]
    [string]$ExistingSamAccountForTesting
  )
  PROCESS {
    
    #This collects the password blob.
    $PasswordBlob = (Get-ADServiceAccount $GMSAAccountName -properties 'MSDS-ManagedPassword').'MSDS-ManagedPassword'
    #This places the password blob in a memory stream.
    $MemoryStream = [IO.MemoryStream]$PasswordBlob
    #This uses a the .Net BinaryReader to allow integer reading of the Memory Stream.
    $Reader = new-object System.IO.BinaryReader($MemoryStream)
    #This reads the version piece of the blob
    $Version = $Reader.ReadInt16()
    #This reads the Reserved piece of the blob
    $Reserved = $Reader.ReadInt16()
    #This reads the length of the blob.
    $Length = $Reader.ReadInt32()
    #This reads the current password offset of the blob.
    $CurrentPwdOffset = $Reader.ReadInt16()
    #This creates an empty string to place the characters of the password in.
    $CurrentPassword = ""
    #This converts the password chunk of the blob into readable characters using BitCoverter, starting on the character identified by the CurrentPassword Offset, stopping at the end of the Password Blob's Length, incrementing each item by 2
    For ($I = $CurrentPwdOffset; $I -lt $PasswordBlob.Length; $I += 2) {
      [char]$Char = [System.BitConverter]::ToChar($PasswordBlob, $i)
      $CurrentPassword += $Char
    }
    
    #This renames the account to a format usable in PSCredential storage for internal authentication.
    $Username = $Domain + ($GMSAAccountName -replace '$', '')
    #This converts the decoded password into a secure string.
    $SecurePassword = $CurrentPassword | ConvertTo-SecureString -AsPlainText -Force
    #This stores the username and password into a credential object.
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword
    #This simply test that the credentials work.
    Get-ADUser $ExistingSamAccountForTesting -credential $Credentials
    
  }
}

function Sync-FeatureBitsTable {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, HelpMessage = "Provide the literal path to the CSV")]
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [string]$csvFile,
        
    [Parameter(Mandatory = $true)]
    [string]$ServerInstance,
        
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName
  )
        
  begin {
  }
        
  process {
        
    $mergevalues = ""
    $azureTableKeys = Import-Csv -Path $csvFile
    $azureTableKeys | ForEach-Object {
      $azurekey = $_
      $insertquery = (",({0},'{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}','{9}')" -f `
          $azurekey.Id,
        $azurekey.CreatedByUser,
        $azurekey.CreatedDateTime,
        $azurekey.ExcludedEnvironments,
        $azurekey.LastModifiedByUser,
        $azurekey.LastModifiedDateTime,
        $azurekey.MinimumAllowedPermissionLevel,
        $azurekey.Name,
        $azurekey.OnOff,
        $azurekey.ExactAllowedPermissionLevel)
        
      $mergevalues += $insertquery
        
    }
        
    $mergevalues = $mergevalues.Substring(1)
        
    $sql = ("SET IDENTITY_INSERT [dbo].[FeatureBitDefinitions] ON
        
        MERGE INTO [dbo].[FeatureBitDefinitions] AS Target
            USING (VALUES
                {0}
                ) AS Source ([Id],[CreatedByUser],[CreatedDateTime],[ExcludedEnvironments],[LastModifiedByUser],[LastModifiedDateTime],[MinimumAllowedPermissionLevel],[Name],[OnOff],[ExactAllowedPermissionLevel])
        ON (Target.[Id] = Source.[Id])
        WHEN MATCHED THEN
        UPDATE SET
           [CreatedByUser] = Source.[CreatedByUser]
           ,[CreatedDateTime] = Source.[CreatedDateTime]
           ,[ExcludedEnvironments] = Source.[ExcludedEnvironments]
           ,[LastModifiedByUser] = Source.[LastModifiedByUser]
           ,[LastModifiedDateTime] = Source.[LastModifiedDateTime]
           ,[MinimumAllowedPermissionLevel] = Source.[MinimumAllowedPermissionLevel]
           ,[Name] = Source.[Name]
           ,[OnOff] = Source.[OnOff]
           ,[ExactAllowedPermissionLevel] = Source.[ExactAllowedPermissionLevel]
        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([Id],[CreatedByUser],[CreatedDateTime],[ExcludedEnvironments],[LastModifiedByUser],[LastModifiedDateTime],[MinimumAllowedPermissionLevel],[Name],[OnOff],[ExactAllowedPermissionLevel])
            VALUES (Source.[Id],Source.[CreatedByUser],Source.[CreatedDateTime],Source.[ExcludedEnvironments],Source.[LastModifiedByUser],Source.[LastModifiedDateTime],Source.[MinimumAllowedPermissionLevel],Source.[Name],Source.[OnOff],Source.[ExactAllowedPermissionLevel])
        ;
        SET IDENTITY_INSERT [dbo].[FeatureBitDefinitions] OFF
        SET NOCOUNT OFF
        " -f $mergevalues)
        
    Write-Verbose $sql
    Invoke-SQLcmd -ServerInstance $ServerInstance -query $sql -Database $DatabaseName
  }
        
  end {
  }
}    

Function Set-ADFSMetadata {
  <#
  .SYNOPSIS
  Short description
  
  .DESCRIPTION
  Long description
  
  .PARAMETER FSUrl
  Parameter description
  
  .PARAMETER StsName
  Parameter description
  
  .EXAMPLE
      Set-ADFSMetadata -FSUrl "fs.test.local" -StsName "ADFS" -WhatIf
  
  .NOTES
  General notes
  #>
  
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    $FSUrl,

    [Parameter(Mandatory = $true)]
    $StsName
  )
  PROCESS {
    $metadataUrl = "https://$FSUrl/federationmetadata/2007-06/federationmetadata.xml"
    
    try {
      [xml]$metadataDoc = (Invoke-WebRequest $metadataUrl).Content
    }
    catch {
      Write-Error "There was an error downloading the metadata: $($_)"
      return
    }
    
    $adfsSTS = Get-SPTrustedIdentityTokenIssuer $StsName -ErrorAction SilentlyContinue -ErrorVariable "myErrors"
    if ($myErrors -ne $null) {
      $msg = $myErrors[0].Exception.Message
      Write-Error "Could not get the ADFS STS in SharePoint: $msg"
      return
    }
    
    $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $enc = [System.Text.Encoding]::UTF8
    
    $sts = $metadataDoc.EntityDescriptor.RoleDescriptor | Where-Object { $_.type -eq "fed:SecurityTokenServiceType" }
    
    # How many signing certs?
    $signCount = ($sts.KeyDescriptor | ? { $_.use -eq "signing" } | Measure-Object).count
    if ($signCount -eq 1) {
      $certB64 = $sts.KeyDescriptor.KeyInfo.X509Data.X509Certificate
      $newCert.Import($enc.GetBytes($certB64))
      Write-Host "Only one ADFS Signing cert:" $newCert.Subject
    }
    else {
      $certB64 = $sts.KeyDescriptor[0].KeyInfo.X509Data.X509Certificate
      $certB64 = $metadataDoc.EntityDescriptor.Signature.KeyInfo.X509Data.X509Certificate
      $newCert.Import($enc.GetBytes($certB64))
      Write-Host "Primary ADFS Signing cert:" $newCert.Subject
    }
    
    if ($newCert.Thumbprint -ne $null -and -not $adfsSTS.SigningCertificate.Equals($newCert)) {
      # Do we need to add the new cert as CA in SharePoint?
      if ((Get-SPTrustedRootAuthority | ? { $_.Certificate.Thumbprint -eq $newCert.Thumbprint }) -eq $null) {
        Write-Host "Adding the ADFS cert" $newCert.Subject "to the SharePoint trust store"
        If ($PSCmdlet.ShouldProcess("Adding the certificate to the STS Trusted Root Authority")) {
          Write-Warning "Whatif: not adding the certificate"
        }
        Else {
          New-SPTrustedRootAuthority -Name $newCert.Subject -Certificate $newCert
        }
      }
      else {
        Write-Warning "NOT adding the ADFS cert $($newCert.Subject) to the SharePoint trust store because it is already there"
      }
            
      # Set the cert in the STS
      Write-Host "Setting the certificate in the ADFS STS"
      if ($PSCmdlet.ShouldProcess("Changing the certificate in the STS") ) {
        Write-Warning "Whatif: not changing the certificate in the STS"
      }
      Else {
        $adfsSTS | Set-SPTrustedIdentityTokenIssuer -ImportTrustCertificate $newCert
      }
    }
    else {
      Write-Warning "The ADFS primary certificate is already the same as in the SharePoint ADFS STS"
    }
  }
}

Function New-DscCompositeResource {
  <#
      .Synopsis
          Short description of the command
      .Description
          Longer description of the command 
      .EXAMPLE
          New-DscCompositeResource -Path "C:\TestModules" -ModuleName "Wakka" -ResourceName "Foo"
      .EXAMPLE
          New-DscCompositeResource -ModuleName "Wakka" -ResourceName "Foo"
      .EXAMPLE
          "Foo","Bar","Baz" | New-DscCompositeResource -ModuleName "Wakka"
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = "$($env:ProgramFiles)\WindowsPowerShell\Modules",

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(      Mandatory, ValueFromPipeline    )]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceName,

    [Parameter(Mandatory = $false)]
    [string]$Author = $env:USERNAME,

    [Parameter(Mandatory = $false)]
    [string]$Company = "Unknown",

    [Parameter(Mandatory = $false)]
    [string]$Copyright = "(c) $([DateTime]::Now.Year) $env:USERNAME. All rights reserved.",

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )
  begin {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $admin -and $Path -eq "$env:ProgramFiles\WindowsPowerShell\Modules") {
      throw "Must be in Administrative context to write to $Path"
    }
       
    $rootModule = Join-Path $Path $ModuleName
    Write-Verbose "Root module path - $RootModule"
      
    $rootModulePSD = Join-Path $rootModule "$($moduleName).psd1" 
    Write-Verbose "Root module metadata file - $rootModulePSD"
      
    $rootModulePath = Join-Path $rootModule "DSCResources"
    Write-Verbose "DSCResources folder path $rootModulePath"

    if (-not (test-path $rootModulePSD)) {
      if ($PSCmdlet.ShouldProcess($rootModule, 'Creating a base module to host DSC Resources')) { 
        New-Item -ItemType Directory -Path $rootModule -Force:$Force | Out-Null
        New-ModuleManifest -Path $rootModulePSD -ModuleVersion '1.0.0' -Author $Author -CompanyName $Company -Description "CompositeResource Main module" -Copyright $Copyright
      }    
    }
    else {
      Write-Verbose "Module and manifest already exist at $rootModulePSD"
    }
      
    if (-not (test-path $rootModulePath) ) {
      if ($PSCmdlet.ShouldProcess($rootModulePath, 'Creating the DSCResources directory')) {                    
        New-Item -ItemType Directory -Path $rootModulePath -Force:$Force | Out-Null
      }
    }
    else {
      Write-Verbose "DSCResources folder already exists at $rootModulePath"
    }
  }
  process {
    $resourceFolder = Join-Path $rootModulePath $ResourceName
    $resourcePSMName = "$($ResourceName).schema.psm1"
    $resourcePSM = Join-Path $resourceFolder $resourcePSMName
    $resourcePSD = Join-Path $resourceFolder "$($ResourceName).psd1"
      
    if ($PSCmdlet.ShouldProcess($resourceFolder, "Creating new resource $ResourceName")) { 
      New-Item -ItemType Directory -Path $resourceFolder -Force:$Force | Out-Null
          
      if ((-not (test-path $resourcePSM)) -or ($force)) { 
        New-Item -ItemType File -Path $resourcePSM -Force:$Force | Out-Null
        Add-Content -Path $resourcePSM -Value "Configuration $ResourceName`r`n{`r`n}"
      }
      if ((-not (test-path $resourcePSD)) -or ($force)) { 
        New-ModuleManifest -Path $resourcePSD -RootModule $resourcePSMName -ModuleVersion '1.0.0' -Author $Author -CompanyName $Company -Copyright $Copyright
      }

    }
      
  }

}

function Export-ADFSMetadata {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$ExportDirectory
  )
  PROCESS {

    Import-Module ADFS

    Get-ADFSClaimsProviderTrust | Out-File ("{0}\cptrusts.txt" -F $ExportDirectory)
    Get-ADFSRelyingPartyTrust | Out-File ("{0}\rptrusts.txt" -F $ExportDirectory)


    Get-Command * -module ADFS
  }

}