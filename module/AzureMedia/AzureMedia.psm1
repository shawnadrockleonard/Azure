Function Install-Choco {
  [CmdletBinding()]
  param()
  process {
    Set-ExecutionPolicy Bypass -force
    If (!(Test-Path -Path "C:\ProgramData\chocolatey")) {
      $env:chocolateyUseWindowsCompression = 'false'
      Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
      choco feature enable -n=allowGlobalConfirmation
    }
  }
}


function Install-AzCopy {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$installPath = (Get-Location)
  )
  PROCESS {


    $azbloburi = "https://aka.ms/downloadazcopy-v10-windows"
    $tempPath = Get-ChildItem Env:\TEMP
    $downloadPath = Join-Path -Path $tempPath.Value -ChildPath "AZCopy"
    $zipFile = (Join-Path -Path $downloadPath -ChildPath "azcopy_windows_amd64.zip")


    if (-not(Test-Path -Path $downloadPath -PathType Container)) {
      New-Item -Path $downloadPath -ItemType Directory -Force
    }

    if (-not(Test-Path -Path $installPath -PathType Container)) {
      New-Item -Path $installPath -ItemType Directory -Force
    }

    $installPath = Resolve-Path -Path $installPath -Verbose:$VerbosePreference


    if (-not (Test-Path $zipFile)) {
      # download AzCopy from BlobStorage
    
      if ($PSVersionTable.PSEdition -eq "Core") {
        Invoke-WebRequest $azbloburi -OutFile $zipFile
      }
      else {
        Start-BitsTransfer -Source $azbloburi -Destination $zipFile
      }

      Expand-Archive -Path $zipFile -DestinationPath $installPath -Force -Verbose:$VerbosePreference

      $azcopyInstance = Get-ChildItem -Path $installPath -Filter "azcopy.exe*" -Recurse | sort-object LastWriteTime -Descending | Select-Object -First 1
      $azCopyDirectory = $azcopyInstance[0].Directory.Name
      $azCopyDirectoryFull = $azcopyInstance[0].Directory.FullName

      $pathChanges = $false
      $userPath = Get-ItemProperty -path "HKCU:\Environment" -Name Path
      if ($userPath.Path.Contains('azcopy_windows')) {
        $paths = $userPath.Path -split ';'
     
        if (($paths | where-object { $_.Contains($azCopyDirectory) } | Measure-Object).Count -le 0) {
          # most likely the previous version is in the path
          $amd = $paths | where-object { $_.Contains('azcopy_windows') } 
          $newPath = $userPath.Path.Replace(("{0};" -f $amd), ("{0};" -f $azCopyDirectoryFull))
          $pathChanges = $true
        }
      }
      else {
        $newPath = ("{0};{1}" -f $userPath.Path, $azCopyDirectoryFull)
        $pathChanges = $true
      }
    
      if ($pathChanges -eq $true) {
        Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $newPath
        Write-Host "Environment has changed, relaunch and run sequential commands." -ForegroundColor Yellow
      }
    }
  }
}

function Write-FileToAzStorage {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
    [string]$file,

    [Parameter(Mandatory = $true)]
    [string]$storageUriWithSasToken

  )
  PROCESS {
    Write-Verbose ("Starting upload {0}" -f $file)
    azcopy copy $file $storageUriWithSasToken
  }
}

function Get-FileNameFromUrl {
  [CmdletBinding()]
  PARAM(
    [string]$hreflink
  )
  PROCESS {
    $filename = $null
    $uri = [System.Uri]::new($hreflink)
    $urlIsFile = [System.IO.Path]::HasExtension($hreflink)
    if ($true -eq $urlIsFile) {
      $filename = [System.IO.Path]::GetFileName($uri.LocalPath);
    }

    Write-Output $filename
  }
}

function Get-FilesFromIIServer {
  <#
    .SYNOPSIS
        Download files from a File Server (NTLM)
#>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$fileDirectory,

    [Parameter(Mandatory = $true)]
    [string]$mediaUrl,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
  )
  PROCESS {

    $creds = $Credential
    IF ($null -eq $Credential) {
      $creds = Get-Credential -Message "Enter password"
    }


    $uri = [System.Uri]::new($mediaUrl)
    $rooturl = ("{0}://{1}" -f $uri.Scheme, $uri.Authority)
    $decoded = [System.Web.HttpUtility]::UrlDecode($uri)
    $folderPaths = $decoded.replace($rooturl, "")

    $outputDir = Join-Path -Path $fileDirectory -ChildPath $folderPaths
    if (!(Test-Path -Path $outputDir -PathType Container)) {
      $outputDir = (New-Item -Path $outputDir -ItemType Container).FullName
    }

    $options = get-command "Start-BitsTransfer" -ErrorAction:SilentlyContinue

    # Ping IIS HTML page to query links
    $httpreq = Invoke-WebRequest -Uri $mediaUrl -Credential $creds
    $httpreq.Links | ForEach-Object {
      $file = ("{0}{1}" -f $rooturl, $_.href)
      $filename = Get-FileNameFromUrl -hreflink $file
      if ($null -ne $filename) {
        Write-Verbose ("Downloading {0}" -f $file)
        Write-Host "This may take a while..." -ForegroundColor Yellow
        #Override the destination folder and append the HREF filepath
        if ($null -eq $options) {
          $outputFile = Join-Path -Path $outputDir -ChildPath $filename
          Invoke-WebRequest $file -OutFile $outputFile -Credential $creds
        }
        else {
          Start-BitsTransfer -Credential $creds -Source $file -Destination $outputDir -Authentication Ntlm
        }
      }
    }
  }
}

function Rename-Pictures {
  <#
  .SYNOPSIS
    Renames pictures.
  
  .DESCRIPTION
      The Rename-Pictures cmdlet to rename pictures to a format where the file creation time is first 
      in the name in this format: . The idea is that 
      
  .PARAMETER Path
    Specifies the path to the folder where image files are located. Default is current location (Get-Location).
  
  .EXAMPLE    
      PS C:\> Rename-Pictures
   
      Description: 
      Renames all the pictures in folder you are in.
  
  .EXAMPLE    
      PS C:\> Rename-Pictures -Path C:\Folder\Pics\ 
  #>
  Param (
    [Parameter(Mandatory = $FALSE)][string]$Path = (Get-Location),
    [Parameter(Mandatory = $FALSE)][string]$BackupFileName = '_backupdata.csv'
  )
  Begin {
    [reflection.assembly]::LoadFile("C:\Windows\Microsoft.NET\Framework\v4.0.30319\System.Drawing.dll")
    $Script:ErrorLogMsg = $Null
    $Script:CorrectPath = $Null
  }
  Process {
    # Workaround for correct path from user
    if ($Path.EndsWith('\\')) {
      $ImgsFound = Get-ChildItem ($Path + '*') -Include *.jpeg, *.png, *.gif, *.jpg, *.bmp, *.png `
      | Select-Object -Property FullName, Name, BaseName, Extension
    }
    else {
      $ImgsFound = Get-ChildItem ($Path + '\\*') -Include *.jpeg, *.png, *.gif, *.jpg, *.bmp, *.png `
      | Select-Object -Property FullName, Name, BaseName, Extension
    }
          
    # If any file was found
    If ($ImgsFound.Count -gt 0) {        
      # Print the number of images found to the user
      Write-Host -Object ("# of pictures suitable for renaming in " + $Path + ": " + $ImgsFound.Count + "`n")
  
      # Array that takes in the old- and the new filename. This is used for saving a backup to .csv
      $BackupData = @()
  
      # Loops through the images found
      foreach ($Img in $ImgsFound) {
        # Gets image data
        $ImgData = New-Object System.Drawing.Bitmap($Img.FullName)
  
        try {
          # Gets 'Date Taken' in bytes
          [byte[]]$ImgBytes = $ImgData.GetPropertyItem(36867).Value
        }
        catch [System.Exception], [System.IO.IOException] {
          [string]$ErrorMessage = ("{0}`tERROR`tDid not change name for {1}. Reason: {2}" -f (Get-Date).ToString('yyyyMMdd HH:mm:ss'), $Img.Name, $Error)
          $Script:ErrorLogMsg += $ErrorMessage + "`r`n"
          Write-Host -ForegroundColor Red -Object $ErrorMessage
  
          # Clears any error messages
          $Error.Clear()
  
          # No reason to continue. Move on to the next file
          continue
        }
  
        # Gets the date and time from bytes
        [string]$dateString = [System.Text.Encoding]::ASCII.GetString($ImgBytes)
        # Formats the date to the desired format
        [string]$dateTaken = [datetime]::ParseExact($dateString, "yyyy:MM:dd HH:mm:ss`0", $Null).ToString('yyyyMMdd_HHmmss')
        # The new file name for the image
        [string]$NewFileName = $dateTaken + '-' + $Img.Name
                  
        $ImgData.Dispose()
        try { 
          Rename-Item -NewName $NewFileName -Path $Img.FullName -ErrorAction Stop
          Write-Host -Object ("Renamed " + $Img.Name + " to " + $NewFileName)
        }
        catch {
          [string]$ErrorMessage = ("{0}`tERROR`tDid not change name for {1}. Reason: {2}" -f (Get-Date).ToString('yyyyMMdd HH:mm:ss'), $Img.Name, $Error)
          $Script:ErrorLogMsg += $ErrorMessage + "`r`n"
          Write-Host -ForegroundColor Red -Object $ErrorMessage
  
          # Clears any previous error messages
          $Error.Clear()
  
          # No reason to continue. Move on to the next file
          continue
        }
                  
        # Collect data to be added to the backup file
        $BUData = New-Object -TypeName System.Object
        $BUData | Add-Member -MemberType NoteProperty -Name "OldName" -Value $Img.Name
        $BUData | Add-Member -MemberType NoteProperty -Name "NewName" -Value $NewFileName
  
        # Add data to backup collection
        $BackupData += $BUData
      } # foreach
  
      try {
        $BackupData | Export-Csv -NoTypeInformation -Path ($Path + $BackupFileName)
      }
      catch [System.Exception] {
        [string]$ErrorMessage = (
          (Get-Date).ToString('yyyyMMdd HH:mm:ss') + "`tERROR`tCould not create " `
            + ($Path + $BackupFileName) + ". Reason: " + $Error
        )
        $Script:ErrorLogMsg += $ErrorMessage + "`r`n"
  
        # Clears any error messages
        $Error.Clear()
      }
    } # if imgcount > 0
    else {
      Write-Host -Object ("Found 0 image files at " + $Path)
    }
  
    # If there was a problem during the run:
    # Print to file, and let user know
    if ($Null -ne $Script:ErrorLogMsg) {
      Out-File -FilePath ($Path + '_errors.log') -InputObject $ErrorLogMsg
      Write-Host -ForegroundColor Red -Object (
        "Errors were found. Please check " + $Path + "_errors.log"
      )
    }
  }
  
  End { }
}

Function Use-FolderDirectory {
  [CmdletBinding()]
  PARAM( )
  PROCESS {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
  
    $SetPathDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $SetPathDialog.ShowDialog() | Out-Null
    $SetPathDialog.SelectedPath
  }
}

function Convert-Mp4ToAac {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.mp4" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i $filename -vn -acodec copy "$NewDirectory\\$basename.aac"
    } # for every file, copy out the aac stream to its own file in the same directory 
  }
}

function Convert-AacToMp3 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.aac" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i "$filename" "$NewDirectory\\$basename.mp3"
    } 
    # for every file, output copy of aac to mp3 to its own file in the same directory      
  }
}
  
function Convert-M4aToMp3 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.m4a" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i "$filename" "$NewDirectory\\$basename.mp3"
    } 
    # for every file, output copy of m4a to mp3 to its own file in the same directory      
  }
}
  
function Convert-Mp3ToM4a {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.mp3" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i "$filename" "$NewDirectory\\$basename.m4a"
    } 
    # for every file, output copy of mp3 to m4a to its own file in the same directory
  }
}  

function Convert-OggToMp3 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    if (!(Test-Path $NewDirectory)) {
      New-Item -Path $NewDirectory -ItemType Container -Force
    }
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.ogg" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName
      ffmpeg -i "$filename" "$NewDirectory\\$basename.mp3"
    } 
  }
}

function Convert-FlacToMp3 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory),
    
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$NewDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    if (!(Test-Path $NewDirectory)) {
      New-Item -Path $NewDirectory -ItemType Container -Force
    }
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.flac" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName
      ffmpeg -i $filename -ab 320k -map_metadata 0 -id3v2_version 3 $NewDirectory\\$basename.mp3
    } 
  }
}
  
function Convert-MkvToMp4 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.mkv" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i $filename -codec copy $FileDirectory\\$basename.mp4
    } 
    # for every file, convert from mkv to mp4 in the same directory  
  }
} 
  
function Convert-AviToMp4 {
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$FileDirectory = (Use-FolderDirectory)
  )
  PROCESS {
    $fileList = Get-ChildItem -Path $FileDirectory -Recurse -Filter "*.avi" | Select-Object FullName, BaseName #get a list of all files in the set path and strip out extension
    foreach ($file in $fileList) { 
      $filename = $file.FullName; 
      $basename = $file.BaseName; 
      ffmpeg -i $filename -c:v copy -c:a copy -y $FileDirectory\\$basename.mp4
    } 
    # for every file, convert from mkv to mp4 in the same directory  
  }
} 
