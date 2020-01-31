

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
  -TemplateFile .\nested\aad-keyvault.json -TemplateParameterFile .\nested\aad-keyvault.parameters.json `
  -KeyVaultName "splcostingkv" -keyVaultSkuName "Premium"
Set-AzKeyVaultAccessPolicy -VaultName "splcostingkv" -UserPrincipalName $sleoId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru
Set-AzKeyVaultAccessPolicy -VaultName "splcostingkv" -UserPrincipalName $shawnId.UserPrincipalName -PermissionsToKeys get, create, import, delete, list, update, recover, backup, restore -PermissionsToSecrets get, list, set, delete, recover, backup, restore -PassThru

# Provision Key for Encryption
Add-AzKeyVaultKey -Name "myKEK" -VaultName "splcostingkv" -Destination "HSM"
$KeyVault = Get-AzKeyVault -VaultName "splcostingkv" -ResourceGroupName "spl-costing"
$KEK = Get-AzKeyVaultKey -VaultName "splcostingkv" -Name "myKEK"


$templateLog = New-AzResourceGroupDeployment -Name "logAnalytics" -ResourceGroupName "spl-costing-logs" -Mode Incremental `
  -TemplateFile .\nested\aad-log-analytics.json `
  -logAnalyticsWorkspaceName "splcostinglogs" -logAnalyticsSku "PerGB2018" -logAnalyticsRetention 90 -Verbose
$logWorkspaceId = $templateLog.Outputs["workspaceCustomerId"].value
$logWorkspaceKey = $templateLog.Outputs["workspaceKey"].value
$logWorkspaceSecureKey = ConvertTo-SecureString -String $logWorkspaceKey -AsPlainText -Force


# For Windows/Log Analytics where LogAnalytics is not available in the region
$oms = Get-AzOperationalInsightsWorkspace -ResourceGroupName "spl-costing-logs" -Name "splcostinglogs" 
$logWorkspaceId = $oms.CustomerId
$logWorkspaceKey = (Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $oms.ResourceGroupName -Name $oms.Name).PrimarySharedKey
$logWorkspaceSecureKey = ConvertTo-SecureString -String $logWorkspaceKey -AsPlainText -Force



$Secure = Read-Host -AsSecureString

New-AzResourceGroupDeployment -Name "encryptedVm" -ResourceGroupName "spl-costing" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/azuredeploy.json" `
  -TemplateParameterFile .\azuredeploy.parameter.json `
  -logAnalyticsWorkspaceId $logWorkspaceId -logAnalyticsWorkspaceKey $logWorkspaceSecureKey `
  -keyVaultResourceGroup "spl-costing" -keyVaultName $KeyVault.VaultName -keyVaultEncryptionUrl $KEK.Id `
  -adminPassword $Secure -Verbose


$vm = Get-AzVM -ResourceGroupName "spl-costing" -Name "vm-splcosting01"
$vmlocation = $vm.Location
Set-AzVMExtension -ResourceGroupName "spl-costing" -VMName "vm-splcosting01" -Name 'MicrosoftMonitoringAgent' -Publisher 'Microsoft.EnterpriseCloud.Monitoring' -ExtensionType 'MicrosoftMonitoringAgent' -TypeHandlerVersion '1.0' `
  -Location $vmlocation -SettingString "{'workspaceId':  '$logWorkspaceId'}" -ProtectedSettingString "{'workspaceKey': '$logWorkspaceKey' }"
  


Get-AzADServicePrincipal | Where-Object DisplayName -Like "*splcosting*"


# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "splcostingkv" --resource-group "spl-costing" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "splcostingkv" --kty RSA-HSM