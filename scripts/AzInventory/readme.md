# Az Inventory

This is a sample script to assist in pulling an inventory of your IaaS resources.

- Disks
- Network Interfaces
- Virtual Networks
- Virtual Network Peerings
- Virtual Machines
- Attached Disks
- Virtual Machine Sizing

The script will read in a JSON file 'config.json' which contains a Storage Account name and key.  
The resulting CSV's will be uploaded into the storage account container 'azinventory'

```JSON
{
    "storageAccountName": "",
    "storageKey": ""
}
```

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fmaster%2Fscripts%2FAzInventory%2Fautomation.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazure.png"/> 
</a>

<a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fmaster%2Fscripts%2FAzInventory%2Fautomation.json" target="_blank">
<img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazuregov.png"/>
</a>
