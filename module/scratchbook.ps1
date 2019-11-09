<#
    .SYNOPSIS
        Download files from a File Server (NTLM)
#>
[CmdletBinding()]
Param()
PROCESS {

    $creds = Get-Credential -Message "Enter password"

    Import-Module .\AzureMedia\AzureMedia.psm1 -Force

    
    Get-FilesFromIIServer -Credential $creds -mediaUrl "https://media.<>.com/t/Arrow/Season 8/" -fileDirectory "c:/temp/media/"

    Write-FileToAzStorage -file "C:\Users\sleonard\Videos\The Wedding Singer.mp4" -storageUriWithSasToken "https://.blob.core.usgovcloudapi.net?sas" -Verbose


    Install-AzCopy -installPath "C:\installtools" -Verbose
}