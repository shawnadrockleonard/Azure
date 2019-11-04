[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, HelpMessage = "https://.sharepoint.com/sites/teamsite")]
    [string]$Url,
    
    [Parameter(Mandatory = $true, HelpMessage = "Provider your UPN, ex: admin@tenant.onmicrosoft.com")]
    [string]$userName,
    
    [Parameter(Mandatory = $true, HelpMessage = "Provider your Application GUID registered in Azure AD.")]
    [string]$appId,
    
    [Parameter(Mandatory = $true, HelpMessage = "Provider your Application name registered in Azure AD, ex: adp_test.")]
    [string]$appName
)
BEGIN {

    $msonline = Get-Module MSOnline -ListAvailable -ErrorAction:SilentlyContinue
    if ($null -eq $msonline) {
        Find-Module MSOnline | Install-Module -Force -Scope CurrentUser
    }
}
PROCESS {

    Get-MsolServicePrincipalCredential -AppPrincipalId $appId -ReturnKeyValues:$true 

    Connect-MsolService

    $apps = Get-MsolServicePrincipal -All | Where-Object { $_.DisplayName -like ('*{0}*' -f $appName) -or $_.AppPrincipalId -eq $appId }
    $apps | Select-Object { $_.ServicePrincipalNames }
    Get-Msoluserrole -ObjectId $apps[0].ObjectId


}