<#

.DEVOPS
    $(System.WorkingDirectory)\policies\Get-ArtifactsFeedName.ps1
        -ArtifactsFeedName "$(ArtifactsFeedName)" 
        -TeamFoundationUri "$(System.TeamFoundationCollectionUri)"

#>
[cmdletbinding()]
param(
    [string]$TeamFoundationUri,
    [string]$ArtifactsFeedName
)


Write-output "TeamFoundationUri: $TeamFoundationUri"
Write-output "ArtifactsFeedName: $ArtifactsFeedName"

$colURI = [uri]::New("$TeamFoundationUri")
if ("$TeamFoundationUri" -match "visualstudio.com")
{
    Write-Output "In Visual Studio if statement"
    $org = $colURI.Authority.split('.')[0]
    $feedURI = "https://pkgs.dev.azure.com/$org/_packaging/$ArtifactsFeedName/nuget/v2"
}
else
{
    Write-Output "In Visual Studio else statement"
    $pkgAuth = "pkgs.$($colURI.Authority)"
    $feedURI = "https://$pkgAuth" + "$($colURI.AbsolutePath)" + "_packaging/$ArtifactsFeedName/nuget/v2"
}


Write-output "Azure Artifacts Feed URI: $feedURI"
Write-Output ("##vso[task.setvariable variable=feedURI]$($feedURI)")
