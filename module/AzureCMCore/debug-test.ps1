Import-Module .\AzureCMCore.dll
Get-Command -Module AzureCMCore
$appId = Get-ChildItem Env:\POSH_API_ID
$appSecret = Get-ChildItem Env:\POSH_API_SECRET
Connect-AzureCMAdal -AppId $appId.Value -AppSecret $appSecret.Value -AADDomain "usepa.onmicrosoft.com"
