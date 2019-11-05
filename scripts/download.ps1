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



    $httpreq = Invoke-WebRequest -Uri $mediaUrl -Credential $creds
    $httpreq.Links | ForEach-Object {
        $file = ("{0}{1}" -f $rooturl, $_.href)
        if ($_.innerText -notcontains "[To Parent Directory]") {
            Write-Output ("Downloading {0}" -f $file)
            #Override the destination folder and append the HREF filepath
            #$output = Join-Path -Path $fileDirectory -ChildPath $_.innerText
            Start-BitsTransfer -Credential $creds -Source $file -Destination $outputDir -Authentication Ntlm
        }
    }
}