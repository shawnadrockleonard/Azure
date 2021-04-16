# Add a subscription tag to resource groups where one does not exist

Adds the specified tag subscription value when any resource group missing this tag is created or updated. 
Existing resource groups can be remediated by triggering a remediation task. 
If the tag exists with a different value it will not be changed.  
Note: As a result of this targetting Resource Group the Mode must be **All** 


## Try on Portal

[![Deploy to Azure](https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazure.png)](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2Fpolicy-definitions%2Fdefault-resourcegroup-ifnotag%2Fazurepolicy.json)   

[![Deploy to Azure Government](https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazuregov.png)](https://portal.azure.us/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2Fpolicy-definitions%2Fdefault-resourcegroup-ifnotag%2Fazurepolicy.json)

## Try with PowerShell

````powershell
$definition = New-AzPolicyDefinition -Name "add-resourcegroup-default-ifnotag" -DisplayName "Add a subscription tag to resource groups" -description "Adds the specified subscription tag value when any resource group missing this tag is created or updated." -Policy 'https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/policy-definitions/default-resourcegroup-ifnotag/azurepolicy.rules.json' -Parameter 'https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/policy-definitions/default-resourcegroup-ifnotag/azurepolicy.parameters.json' -Mode All
$definition

$assignment = New-AzPolicyAssignment -Name "add-resourcegroup-default-ifnotag-assignment" -Scope <scope> -tagName <tagName> -PolicyDefinition $definition -AssignIdentity -Location <region>
$assignment 
````