<#

.DEVOPS
    $(System.WorkingDirectory)\policies\Get-ArtifactFeedName.ps1
        -ArtifactFeedName "$(ArtifactFeedName)" 
        -TeamFoundationUri "$(System.TeamFoundationCollectionUri)"

#>
[cmdletbinding()]
param(
    [string]$TeamFoundationUri,
    [string]$ArtifactFeedName
)


$colURI = [uri]::New("$TeamFoundationUri")
if ("$TeamFoundationUri" -match "visualstudio.com")
{
    $org = $colURI.Authority.split('.')[0]
    $feedURI = "https://pkgs.dev.azure.com/$org/_packaging/$ArtifactsFeedName/nuget/v2"
}
else
{
    $pkgAuth = "pkgs.$($colURI.Authority)"
    $feedURI = "https://$pkgAuth" + "$($colURI.AbsolutePath)" + "_packaging/$ArtifactsFeedName/nuget/v2"
}


Write-output "Azure Artifacts Feed URI: $feedURI"
Write-Output ("##vso[task.setvariable variable=feedURI]$($feedURI)")
