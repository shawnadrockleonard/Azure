

# Set environment, if not commercial
Connect-AzAccount

# Get-AzSubscription (in case your login has more than 1 subscription)
# Select-AzSubscription -Subscription "<guid>"

# Discovery where KeyVault is supported
Get-AzLocation | where Providers -contain 'Microsoft.KeyVault' | select Location | sort location 

# Provision the resource group [NOTE this location must be the same for both KeyVault and Virtual Machines]
New-AzResourceGroup -Name "cmscosting" -Location "northcentralus"

# Find a user to associate with an Access Policy [searching for a user starting with sleo]
$userId = Get-AzADUser -StartsWith "sle"

New-AzResourceGroupDeployment -Name "keyvault" -ResourceGroupName "cmscosting" -Mode Incremental `
  -TemplateFile .\nested\cms-costing-keyvault.json -TemplateParameterFile .\nested\cms-costing-keyvault.parameters.json `
  -KeyVaultName "cmscosting-kv" -userAadId $userId.Id

# Provision Key for Encryption
Add-AzKeyVaultKey -Name "myKEK" -VaultName "cmscosting-kv" -Destination "HSM"
$KeyVault = Get-AzKeyVault -VaultName "cmscosting-kv" -ResourceGroupName "cmscosting"
$KEK = Get-AzKeyVaultKey -VaultName "cmscosting-kv" -Name "myKEK"


$Secure = Read-Host -AsSecureString



# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "cmscosting-kv" --resource-group "cmscosting" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "cmscosting-kv" --kty RSA-HSM