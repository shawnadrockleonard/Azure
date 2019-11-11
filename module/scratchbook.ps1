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



    Import-Module .\AzureServer\AzureServer.psm1 -Force

    $Path = (Get-Location)
    $splat = @{
        Path         = $Path
        ModuleName   = 'MyDSCComposite'
        ResourceName = 'MyDSCBaseline'
        Author       = 'Shawn Leonard'
        Company      = 'Microsoft'
    }

    New-DscCompositeResource @splat


    $ADFSSiteName = "sts"
    $DomainFQDN = "my-test.internalname.us" 
    
    
    foreach ($stsSite in @(
            @{ Site = "https://appidentity-mytest.azurewebsites.us";  
                ForwardLooking = "appidentity-mytest"; Name = 'AzureASE'; Zone = "1" 
            }, 
            @{ Site = ("https://{0}.{1}" -f $ADFSSiteName, $DomainFQDN); 
                ForwardLooking = ("{0}" -f $ADFSSiteName); Name = 'ADFS'; Zone = "1" 
            }
        )) {
              
        $SiteDomainFQDN = $stsSite.Site -replace ("https://{0}." -f $stsSite.ForwardLooking), ""
        $DomainNetbiosName = Get-NetBIOSName -DomainFQDN $SiteDomainFQDN
        $TrustedSiteDomain = Get-NetBIOSForest -DomainFQDN $SiteDomainFQDN
        $TrustedForwardLooking = "{0}.{1}" -f $stsSite.ForwardLooking, $DomainNetbiosName
        Write-Host  ("AddTrustedSiteZoneEntries-{0}" -f $stsSite.Name) 
        Write-Host ("AddTrustedSiteZoneEntries-{0}-ZoneMap" -f $stsSite.Name)
        Write-Host ("HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\{0}\{1}" -f $TrustedSiteDomain, $TrustedForwardLooking)
    }       
}