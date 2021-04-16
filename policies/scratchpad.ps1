
# Fix for DeviceCode
# https://www.pipehow.tech/new-psrepository/
# Install Beta Module
Install-Module PowerShellGet -AllowPrerelease -Force -Scope CurrentUser
get-command -module powershellget

$ArtifactsFeedName = "AzPolicy"
$feedURI = "https://pkgs.dev.azure.com/shawniq/_packaging/AzPolicy/nuget/v2"

$patToken = ConvertTo-SecureString -String "<get from keyvault>" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("sleonard@microsoft.com", $patToken)


# Adding PSGallery since I didn't have it by default
Register-PSResourceRepository -PSGallery -ErrorAction SilentlyContinue

# Registering our Azure Artifacts repository with the v2 URL as a trusted repository
$repo = Get-PSResourceRepository -Name $ArtifactsFeedName -ErrorAction SilentlyContinue
if ($null -eq $repo)
{
    Register-PSResourceRepository -Name $ArtifactsFeedName -URL $feedURI -Trusted
}

Get-PSResourceRepository

Install-Module "Pester" -Repository PSGallery -RequiredVersion 4.7.0 -force -scope CurrentUser
Install-PSResource 'AzTestPolicy' -Repository $ArtifactsFeedName -Credential $credential -scope CurrentUser


import-module aztestpolicy -Force  


