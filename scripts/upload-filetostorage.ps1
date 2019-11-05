
[CmdletBinding()]
Param(
  [Parameter(Mandatory = $true)]
  [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
  [string]$file,
  [Parameter(Mandatory = $false)]
  [string]$storageUri = "https://armholder.blob.core.usgovcloudapi.net",
  [Parameter(Mandatory = $false)]
  [string]  $sas = "?st=2019-10-25T21%3A03%3A30Z&se=2019-11-26T20%3A03%3A00Z&sp=racwl&sv=2018-03-28&sr=c&sig=b6MXJaJ5JrhiCaXjW3XJ8MedBQjYGUs5hJdpSlI53uQ%3D"
)
BEGIN {
  $sasuri = ("{0}/media{1}" -f $storageUri, $sas)
}
PROCESS {

  Function Start-Command {
    Param([Parameter (Mandatory = $true)]
      [string]$Command, 
      [Parameter (Mandatory = $true)]
      [string]$Arguments)

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $Command
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    [pscustomobject]@{
      stdout   = $p.StandardOutput.ReadToEnd()
      stderr   = $p.StandardError.ReadToEnd()
      ExitCode = $p.ExitCode  
    }
  }

  $azbloburi = ("{0}/files/azcopy_windows_amd64_10.2.1.zip{1}" -f $storageUri, $sas)
  $outputPath = Join-Path -Path "." -ChildPath "scripts" -Resolve
  $azCopyExe = ("{0}/AzCopy.exe" -f $outputPath)


  if ($PSVersionTable.PSEdition -eq "Core") {
    Install-Module WindowsCompatibility  -Scope CurrentUser 
    #Import-WinModule BitsTransfer
  }

  if (-not (Test-Path $azCopyExe)) {
    # download AzCopy from BlobStorage
    Invoke-WebRequest $azbloburi -OutFile (Join-Path -Path $outputPath -ChildPath "azcopy_windows_amd64_10.2.1.zip")
    #Start-BitsTransfer -Source $azbloburi -Destination $outputPath
  
    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::ExtractToDirectory($(Join-Path $outputPath "azcopy_windows_amd64_10.2.1.zip"), $outputPath)

    # re-define variable to output path as we downloaded the files just in time
    $azCopyExe = ("{0}/AzCopy.exe" -f $outputPath)
  }



  $result = Start-Command -Command "`"$azCopyExe`"" -Arguments "$file" "$sasuri"
  Write-Host $result
  


}