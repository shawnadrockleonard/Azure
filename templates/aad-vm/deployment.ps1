

# Set environment, if not commercial
Connect-AzAccount
Connect-AzAccount -Environment AzureUSGovernment

# Get-AzSubscription (in case your login has more than 1 subscription)
# Select-AzSubscription -Subscription "<guid>"

# Discovery where KeyVault is supported
Get-AzLocation | Where-Object Providers -contain 'Microsoft.KeyVault' | Select-Object Location | Sort-Object location 

# Provision the resource group [NOTE this location must be the same for both KeyVault and Virtual Machines]
New-AzResourceGroup -Name "spl-costing" -Location "westus"
New-AzResourceGroup -Name "spl-costing-logs" -Location "eastus"

# Find a user to associate with an Access Policy [searching for a user starting with sleo]
$sleoId = Get-AzADUser -StartsWith "shawn leo"
$shawnId = Get-AzADUser -StartsWith "shawn"

New-AzResourceGroupDeployment -Name "keyvault" -ResourceGroupName "spl-costing" -Mode Incremental `
  -TemplateFile .\nested\cms-costing-keyvault.json -TemplateParameterFile .\nested\cms-costing-keyvault.parameters.json `
  -KeyVaultName "splcostingkv" -keyVaultSkuName "Premium"
Set-AzKeyVaultAccessPolicy -VaultName "splcostingkv" -UserPrincipalName $sleoId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru
Set-AzKeyVaultAccessPolicy -VaultName "splcostingkv" -UserPrincipalName $shawnId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru

# Provision Key for Encryption
Add-AzKeyVaultKey -Name "myKEK" -VaultName "splcostingkv" -Destination "HSM"
$KeyVault = Get-AzKeyVault -VaultName "splcostingkv" -ResourceGroupName "spl-costing"
$KEK = Get-AzKeyVaultKey -VaultName "splcostingkv" -Name "myKEK"


$Secure = Read-Host -AsSecureString

New-AzResourceGroupDeployment -Name "encryptedVm" -ResourceGroupName "spl-costing" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/azuredeploy.json" `
  -TemplateParameterFile .\azuredeploy.parameter.json `
  -logAnalyticsResourceGroup "spl-costing-logs" -logAnalyticsLocation "usgovarizona" `
  -keyVaultResourceGroup "spl-costing" -keyVaultName $KeyVault.VaultName -keyVaultEncryptionUrl $KEK.Id -systemName "splcosting" `
  -adminUsername "spluser" -adminPassword $Secure -Verbose


Get-AzADServicePrincipal | Where-Object DisplayName -Like "*splcosting*"


# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "splcostingkv" --resource-group "spl-costing" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "splcostingkv" --kty RSA-HSM