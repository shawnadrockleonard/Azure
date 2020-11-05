# Azure Subscription Policies

This is a demo repository that contains:

**Azure Resource Manager Templates for Policy:** Azure policies can be curated or deployed via the Azure Portal or through scripts.  These policies help ensure your resources adhere to corporate/agency standards.  

- There are 2 policy definitions contained here:
    1. [default-resourcegroup-ifnotag](https://github.com/shawnadrockleonard/Azure/tree/shawns/dotnetcore/policy-definitions/default-resourcegroup-ifnotag) enables Add/Update Resource Group tag from the Subscription Tag if one does not exist or is empty
    2. [default-resourcegroup-overwritetag](https://github.com/shawnadrockleonard/Azure/tree/shawns/dotnetcore/policy-definitions/default-resourcegroup-overwritetag) enables Overwrite Resource Group tag from the Subscription Tag regardless of its value.


## Tutorials
- [Azure Policy built-in policy definitions](https://docs.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies)
- [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure)
- [Tutorial: Create and manage policies to enforce compliance](https://docs.microsoft.com/en-us/azure/governance/policy/tutorials/create-and-manage)
- [Tutorial: Manage tag governance with Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/tutorials/govern-tags)

## Samples / Templates / Source
You can find Azure Policy community templates on [github](https://github.com/Azure/azure-policy)