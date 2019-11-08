[CmdletBinding()]
Param(
  [Parameter(Mandatory = $true)]
  [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
  [string]$file,
  
  [Parameter(Mandatory = $true)]
  [string]$storageUri,

  [Parameter(Mandatory = $false)]
  [string]$sas = "?st=2019-10-25T21%3A03%3A30Z&se=2019-11-26T20%3A03%3A00Z&sp=racwl&sv=2018-03-28&sr=c&sig=b6MXJaJ5JrhiCaXjW3XJ8MedBQjYGUs5hJdpSlI53uQ%3D"
)
BEGIN {
  $installPath = "C:\\installtools"
  $sasuri = ("{0}/media{1}" -f $storageUri, $sas)
}
PROCESS {


  $azbloburi = "https://aka.ms/downloadazcopy-v10-windows"
  $outputPath = Join-Path -Path "." -ChildPath "scripts" -Resolve
  $downloadPath = Join-Path -Path $outputPath -ChildPath "AZCopy"
  if (-not(Test-Path -Path $downloadPath -PathType Container)) {
    New-Item -Path $downloadPath -ItemType Directory -Force
  }
  $azCopyExe = Join-Path -Path $downloadPath -ChildPath "AzCopy.exe"

  if (-not(Test-Path -Path $installPath -PathType Container)) {
    New-Item -Path $installPath -ItemType Directory -Force
  }


  if (-not (Test-Path $azCopyExe)) {
    # download AzCopy from BlobStorage
    $zipFile = (Join-Path -Path $downloadPath -ChildPath "azcopy_windows_amd64.zip")
    
    if ($PSVersionTable.PSEdition -eq "Core") {
      Invoke-WebRequest $azbloburi -OutFile $zipFile
      #Import-WinModule BitsTransfer
    }
    else {
      Start-BitsTransfer -Source $azbloburi -Destination $zipFile
    }

    Expand-Archive -Path $zipFile -DestinationPath $installPath -Force -Verbose:$VerbosePreference

    $azcopyInstance = Get-ChildItem -Path $installPath -Filter "azcopy.exe*" -Recurse | sort-object LastWriteTime -Descending | Select-Object -First 1
    $azCopyExe = $azcopyInstance[0].FullName
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
    }
  }



  Write-Host $result
  azcopy copy $file $sasuri
}