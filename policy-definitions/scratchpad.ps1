Add-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication
Select-AzSubscription -Subscription "spl-mag"
$subscription = (Get-AzSubscription -SubscriptionName "spl-mag")[0]
$location = (Get-AzLocation)[0]

# RBAC
# Get-AzRoleDefinition | FT Name, Id
# Contributor b24988ac-6180-42a0-ab88-20f7382dd24c

# Schema
# https://schema.management.azure.com/schemas/2019-09-01/policyDefinition.json


$definition = New-AzPolicyDefinition -Name "subscription-resource-ifnotag" -Description "Provides subscription tag, defaulting to Resource group" `
    -Policy 'C:\Repos\shawnadrockleonard\Azure\policy-definitions\default-resourcegroup-tag\azurepolicy.rules.json' `
    -Parameter 'C:\Repos\shawnadrockleonard\Azure\policy-definitions\default-resourcegroup-tag\azurepolicy.parameters.json' `
    -Metadata '{"category":"Tags"}' -Mode Indexed -Verbose

$definition

$assignment = New-AzPolicyAssignment -Name "subscription-resource-ifnotag-assignment" -Scope "/subscriptions/$($Subscription.Id)" -tagName 'Customer' `
    -PolicyDefinition $definition -AssignIdentity  -Location $location.Location
$assignment 
