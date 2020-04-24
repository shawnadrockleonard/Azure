

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

$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName armbastion
$workspaceKeys = $workspace | Get-AzOperationalInsightsWorkspaceSharedKey
$workspaceSecure = ConvertTo-SecureString -String $workspaceKeys.PrimarySharedKey -AsPlainText -Force
New-AzResourceGroupDeployment -Name ("{0}-ext-logs" -f $vmName) -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/nested/aad-vm-ext-logs.json" `
  -vmName $vmName -location "usgovvirginia" -logAnalyticsWorkspaceId $workspace.CustomerId -logAnalyticsWorkspaceKey $workspaceSecure

New-AzResourceGroupDeployment -Name ("{0}-ext-network" -f $vmName) -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/nested/aad-vm-ext-networkWatcher.json" `
  -vmName $vmName -location "usgovvirginia" -Verbose

New-AzResourceGroupDeployment -Name ("{0}-ext-encryption" -f $vmName) -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/nested/aad-vm-ext-encryption.json" `
  -vmName $vmName -location "usgovvirginia" -keyVaultName $KeyVault.VaultName -keyVaultEncryptionUrl $KEK.Id -vmEncryptionType "OS" -Verbose

New-AzResourceGroupDeployment -Name ("{0}-ext-malware" -f $vmName) -ResourceGroupName "armbastion" -Mode Incremental `
  -TemplateUri "https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/aad-vm/nested/aad-vm-ext-malware.json" `
  -vmName $vmName -location "usgovvirginia" -Verbose




Get-AzADServicePrincipal | Where-Object DisplayName -Like "*splcosting*"


# https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az cloud set --name AzureCloud
az login
az account set --subscription "<subscription-guid>"
az keyvault update --name "splcostingkv" --resource-group "armbastion" --enabled-for-template-deployment "true"
az keyvault key create --name "myKEK" --vault-name "splcostingkv" --kty RSA-HSM




# Set variables
$resourceGroup = "armbastion"
$vmName = "vm-build02"
$newAvailSetName = "vm-splcosting-va-set"

# Get the details of the VM to be moved to the Availability Set
$originalVM = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName

# Create new availability set if it does not exist
$availSet = Get-AzAvailabilitySet -ResourceGroupName $resourceGroup -Name $newAvailSetName  -ErrorAction Ignore
 

# Remove the original VM
Remove-AzVM -ResourceGroupName $resourceGroup -Name $vmName    

# Create the basic configuration for the replacement VM. 
$newVM = New-AzVMConfig -VMName $vmName -VMSize "Standard_B16ms" -AvailabilitySetId $availSet.Id

# For a Linux VM, change the last parameter from -Windows to -Linux 
Set-AzVMOSDisk `
  -VM $newVM -CreateOption Attach `
  -ManagedDiskId $osdisk.Id -Name $osdisk.Name -Windows

Add-AzVMNetworkInterface `
  -VM $newVM -Id $nic.Id -Primary

# Recreate the VM
New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Location $availSet.Location `
  -VM $newVM `
  -DisableBginfoExtension


Get-Command Set-Az*Extension*



$nic = Get-AzNetworkInterface -Name "vm-splcosting02-nic01" -ResourceGroupName "armbastion"
$nic.EnableAcceleratedNetworking = $False
$nic | Set-AzNetworkInterface