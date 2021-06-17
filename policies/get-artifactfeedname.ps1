


$colURI = [uri]::New("$(System.TeamFoundationCollectionUri)")
if ("$(System.TeamFoundationCollectionUri)" -match "visualstudio.com")
{
    $org = $colURI.Authority.split('.')[0]
    $feedURI = "https://pkgs.dev.azure.com/$org/_packaging/" + "$(ArtifactsFeedName)" + "/nuget/v2"
}
else
{
    $pkgAuth = "pkgs.$($colURI.Authority)"
    $feedURI = "https://$pkgAuth" + "$($colURI.AbsolutePath)" + "_packaging/" + "$(ArtifactsFeedName)" + "/nuget/v2"
}
Write-output "Azure Artifacts Feed URI: $feedURI"
Write-Output ("##vso[task.setvariable variable=feedURI]$($feedURI)")

