[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [String]$SubscriptionName,

    [Parameter(Mandatory = $true)]
    [String]$TagName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("AzureUSGovernment", "AzureChinaCloud", "AzureCloud")]
    [string]$AzureEnvironment = "AzureCloud"
)
BEGIN {

    Add-AzAccount -Environment $AzureEnvironment -UseDeviceAuthentication
    
}
PROCESS {

    
    Select-AzSubscription -Subscription $SubscriptionName
    $subscription = (Get-AzSubscription -SubscriptionName $SubscriptionName)[0]
    $location = (Get-AzLocation)[0]

    # RBAC
    # Get-AzRoleDefinition | FT Name, Id
    # Contributor b24988ac-6180-42a0-ab88-20f7382dd24c

    # Schema
    # https://schema.management.azure.com/schemas/2019-09-01/policyDefinition.json


    $definition = New-AzPolicyDefinition -Name "subscription-resource-ifnotag" -Description "Provides defaulting Resource group tag from subscription" `
        -Policy '.\default-resourcegroup-ifnotag\azurepolicy.rules.json' `
        -Parameter '.\default-resourcegroup-ifnotag\azurepolicy.parameters.json' `
        -Metadata '{"category":"Tags"}' -Mode All -Verbose

    $definition

    $assignment = New-AzPolicyAssignment -Name "subscription-resource-ifnotag-assignment" -Scope "/subscriptions/$($Subscription.Id)" -tagName $TagName `
        -PolicyDefinition $definition -AssignIdentity -Location $location.Location
    $assignment 

}