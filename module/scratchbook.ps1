<#
    .SYNOPSIS
        Download files from a File Server (NTLM)
#>
[CmdletBinding()]
Param()
PROCESS {

    $creds = Get-Credential -Message "Enter password"

    Import-Module .\AzureMedia\AzureMedia.psm1 -Force

    
    Get-FilesFromIIServer -Credential $creds -mediaUrl "https://media.<>.com/t/" -fileDirectory "c:/temp/media/"


    Get-ProductKey



    $Path = (Get-Location)
    $splat = @{
        Path         = $Path
        ModuleName   = 'MyDSCComposite'
        ResourceName = 'MyDSCBaseline'
        Author       = 'Shawn Leonard'
        Company      = 'Microsoft'
    }

    New-DscCompositeResource @splat

       
}