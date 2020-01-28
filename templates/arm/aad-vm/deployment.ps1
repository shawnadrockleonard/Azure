

# Set environment, if not commercial
Connect-AzAccount

# Get-AzSubscription (in case your login has more than 1 subscription)
# Select-AzSubscription -Subscription "<guid>"

# Discovery where KeyVault is supported
Get-AzLocation | where Providers -contain 'Microsoft.KeyVault' | select Location | sort location 

# Provision the resource group [NOTE this location must be the same for both KeyVault and Virtual Machines]
New-AzResourceGroup -Name "cms-costing" -Location "westus"

# Find a user to associate with an Access Policy [searching for a user starting with sleo]
$subscription = Get-AzSubscription -SubscriptionName "MyUltimateMSDN"
$sleoId = Get-AzADUser -StartsWith "sle"
$shawnId = Get-AzADUser -StartsWith "shawn"

New-AzResourceGroupDeployment -Name "keyvault" -ResourceGroupName "cms-costing" -Mode Incremental `
  -TemplateFile .\nested\cms-costing-keyvault.json -TemplateParameterFile .\nested\cms-costing-keyvault.parameters.json `
  -KeyVaultName "cmscostingkv" -keyVaultSkuName "Premium"
Set-AzKeyVaultAccessPolicy -VaultName 'cmscostingkv' -UserPrincipalName $sleoId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru
Set-AzKeyVaultAccessPolicy -VaultName 'cmscostingkv' -UserPrincipalName $shawnId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru

# Provision Key for Encryption
Add-AzKeyVaultKey -Name "myKEK" -VaultName "cmscostingkv" -Destination "HSM"
$KeyVault = Get-AzKeyVault -VaultName "cmscostingkv" -ResourceGroupName "cms-costing"
$KEK = Get-AzKeyVaultKey -VaultName "cmscostingkv" -Name "myKEK"


$Secure = Read-Host -AsSecureString

New-AzResourceGroupDeployment -Name "encryptedVm" -ResourceGroupName "cms-costing" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/arm/aad-vm/cms-costing.template.json" `
  -TemplateParameterFile .\cms-costing.parameter.json `
  -keyVaultResourceGroup "cms-costing" -keyVaultName $KeyVault.VaultName -keyVaultEncryptionUrl $KEK.Id -systemName "cmshosting" `
  -adminUsername "spluser" -adminPassword $Secure -Verbose


# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "cmscostingkv" --resource-group "cms-costing" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "cmscostingkv" --kty RSA-HSM