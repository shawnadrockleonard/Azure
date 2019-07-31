$Url = "https://.sharepoint.com/sites/teamsite"
$userName = "admin@.onmicrosoft.com"
$password = Read-Host -Prompt "Please enter your password" -AsSecureString
$appId = ""

<#
sleonard@.onmicrosoft.com

#>


$appId = ""
Get-MsolServicePrincipalCredential -AppPrincipalId $appId -ReturnKeyValues:$true 



Connect-MsolService

$apps = Get-MsolServicePrincipal -All | Where-Object { $_.DisplayName -like '*adp_test*' -or $_.AppPrincipalId -eq $appId }
$apps | Select-Object { $_.ServicePrincipalNames }
Get-Msoluserrole -ObjectId $apps[0].ObjectId