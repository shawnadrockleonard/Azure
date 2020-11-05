# Deploy a secure Windows (Server or Desktop) virtual machine for developer

This template allows you to deploy a virtual machine that has the following capabilities:
- A dedicated virtual network. This will create or augment a virtual network.  Note this uses an incremental deployment technique.
- [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) service to avoid Internet exposure on your virtual machine 
- [Microsoft Antimalware solution for Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/iaas-antimalware-windows)
- Visual Studio Code is installed.
- Key Vault (Premium) must be created prior to running the deployment.
- Disk is encrypted with [Azure Disk Encryption](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disk-encryption-overview) extension support.
- Log Analytics integration to allow virtual machine log to be sent to.



<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2Ftemplates%2Faad-vm%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazure.png"/> 
</a>


<a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2Ftemplates%2Faad-vm%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/deploytoazuregov.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2Ftemplates%2Faad-vm%2Fnested%2Faad-vm.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/master/templates/metadata/visualizebutton.png"/> 
</a>