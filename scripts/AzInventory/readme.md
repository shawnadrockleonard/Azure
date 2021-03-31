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

