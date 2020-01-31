

# Set environment, if not commercial
Connect-AzAccount
Connect-AzAccount -Environment AzureUSGovernment

# Get-AzSubscription (in case your login has more than 1 subscription)
# Select-AzSubscription -Subscription "<guid>"

# Discovery where KeyVault is supported
Get-AzLocation | Where-Object Providers -contain 'Microsoft.KeyVault' | Select-Object Location | Sort-Object location 

# Provision the resource group [NOTE this location must be the same for both KeyVault, Log Analytics and Virtual Machines]
New-AzResourceGroup -Name "armbastion" -Location "westus"


New-AzResourceGroupDeployment -Name "keyvault" -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateFile .\nested\aad-keyvault.json -TemplateParameterFile .\nested\aad-keyvault.parameters.json `
  -KeyVaultName "splcostingkv" -keyVaultSkuName "Premium"
# Find a user to associate with an Access Policy [searching for a user starting with sleo]
$users = Get-AzADUser -StartsWith "shawn leo"
foreach ($user in $users) {
  Set-AzKeyVaultAccessPolicy -VaultName "splcostingkv" -UserPrincipalName $user.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru
}

# Provision Key for Encryption
Add-AzKeyVaultKey -Name "myKEK" -VaultName "splcostingkv" -Destination "HSM"
$KeyVault = Get-AzKeyVault -VaultName "splcostingkv" -ResourceGroupName "armbastion"
$KEK = Get-AzKeyVaultKey -VaultName "splcostingkv" -Name "myKEK"


# Add vmloginname and vmloginpwd to the key vault as your username and password
New-AzResourceGroupDeployment -Name "encryptedVm" -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/azuredeploy.json" `
  -TemplateParameterFile .\azuredeploy.parameter.json `
  -keyVaultName $KeyVault.VaultName -keyVaultEncryptionUrl $KEK.Id -Verbose


Get-AzADServicePrincipal | Where-Object DisplayName -Like "*splcosting*"


# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "splcostingkv" --resource-group "armbastion" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "splcostingkv" --kty RSA-HSM