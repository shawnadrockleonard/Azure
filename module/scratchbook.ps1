<#
    .SYNOPSIS
        Download files from a File Server (NTLM)
#>
[CmdletBinding()]
Param()
BEGIN {
    # MAKE SURE CMDLETS ARE AVAILABLE
    Import-Module .\AzureMedia\AzureMedia.psm1 -Force
}
PROCESS {

    
    

    $creds = Get-Credential -Message "Enter password"
    Get-FilesFromIIServer -Credential $creds -mediaUrl "https://media.<>.com/t/" -fileDirectory "c:/temp/media/"


    Get-ProductKey

       
}