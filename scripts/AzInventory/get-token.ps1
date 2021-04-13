<#
.SYNOPSIS
Generates Access Token for testing.
.DESCRIPTION
Generates Access Token for testing.

The script calls Connect-AzAccount to require authentication before it can start generating/updating a bearer token.

.EXAMPLE
get-token.ps1

#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzInventory/readme.md", SupportsShouldProcess = $true)]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType Container })]
    [string]$RunningDirectory,

    [Parameter(Mandatory = $false)]
    [string]$subscription = "ATR_Production",

    [Parameter(Mandatory = $false)]
    [Switch]$InitiateConnect
)
BEGIN
{

    function Get-AzureServiceToken
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $TRUE)]
            $AzProfile
        )
        PROCESS
        {
            $currentAzureContext = Get-AzContext
            $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($AzProfile)
            Write-Verbose ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
            $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
            Write-Output $token
        }
    }


    if ($InitiateConnect)
    {
        Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication
    }    


    $AzProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $AzProfile.Accounts.Count)
    {
        Write-Error "Please run Connect-AzAccount before calling this function."
        break
    }
        
        
    $token = Get-AzureServiceToken -AzProfile $AzProfile
    Write-Debug $token.AccessToken


    $SubsList = Get-AzSubscription | Where-Object { $_.state -eq "Enabled" }
    Write-Output $SubsList
}