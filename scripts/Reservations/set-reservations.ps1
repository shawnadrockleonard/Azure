<#
Shawn Leonard
Cloud Solution Architect - Azure PaaS & Office365 | Microsoft Federal
BLOG – https://aka.ms/shawniq/   
LinkedIn - https://aka.ms/shawn-linkedin 

.DESCRIPTION
- Will update access policies on reservations

.EXAMPLE
    .\scripts\reservations\set-reservations.ps1 -BillingObjectId <guid> -Verbose
    .\scripts\reservations\set-reservations.ps1 -BillingObjectId <guid> -ReservationRoleName reader -Verbose    

#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/reservations/readme.md", SupportsShouldProcess = $true)]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The AzureAD Object Id for the User, Group, Service Principal")]
    [string]$BillingObjectId,
    
    [Parameter(Mandatory = $false, HelpMessage = "The level of access to grant.")]
    [ValidateSet("owner", "contributor", "reader")]
    [string]$ReservationRoleName = "owner",

    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType Container })]
    [string]$RunningDirectory
)
BEGIN
{
    # Specifies the directory in which this should run
    $runningscriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if ($RunningDirectory -eq "")
    {
        $RunningDirectory = $runningscriptDirectory
    }
        
    $logDirectory = Join-Path -Path $RunningDirectory -ChildPath "_logs"
    if (!(Test-Path -Path $logDirectory -PathType Container))
    {
        New-Item -Path $logDirectory -Force -ItemType Directory -WhatIf:$false | Out-Null
        $logDirectory = Join-Path -Path $RunningDirectory -ChildPath '_logs' -Resolve
    }

    $AzContext = Get-AzContext
    if ($null -eq $AzContext)
    {
        Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication -ErrorAction Break
    }     

    $AzProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $AzProfile.Accounts.Count)
    {
        Write-Error "Please run Connect-AzAccount before calling this function."
        break
    }
}
PROCESS
{

    # Access Policies
    $toBeAssignedRole = Get-AzRoleDefinition -Name $ReservationRoleName
    $AzAssignedRoleName = $toBeAssignedRole.Name

    # User Information
    $account = (Get-AzContext).Account
    $user = (Get-AzADUser -UserPrincipalName $account).DisplayName
    Write-Verbose "User $user executing reservation access policies."


    $orders = Get-AzReservationOrder | Select-Object Id, Name, Reservations, Term, RequestDateTime
    $orders | ForEach-Object { 
        $orderobj = $_
        $orderId = $orderobj.Name 
        
        $role = Get-AzRoleAssignment -ObjectId $BillingObjectId -RoleDefinitionName $AzAssignedRoleName -Scope $orderId -ErrorAction SilentlyContinue
        if ($null -eq $role)
        {
            New-AzRoleAssignment -ObjectId $BillingObjectId -RoleDefinitionName $AzAssignedRoleName -Scope $orderId    
        }
    }
}
END
{
    Write-Host "Finished ..."
}
