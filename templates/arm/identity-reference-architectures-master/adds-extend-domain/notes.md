## Instructions

- Complete all passwords and shared secret keys on the 2 connections. Optionally change the user names.
- Run azbb with 
    - onprem.json
    - azure.json

## More info

### DSC scripts
- onprem-primary.ps1: set ups the AD forest, DNS, RSAT and the replication site, link and subnet (on ad-vm1 - onpremise-vnet)
- onprem-secondary.ps1: set ups DNS, RSAT and a secondary domain controller (on ad-vm2 - onpremise-vnet)
- azure.ps1: set ups set ups DNS, RSAT and a secondary domain controller (on both adds-vm1 and adds-vm2 - adds-vnet)

### azbb2 parameter files
- onprem.json: set ups the onpremise-vnet and vpn gateway, creates ad-vm1 and ad-vm2 VMs, runs onprem-primary.ps1 and onprem-secondary.ps1 DSC scripts
- azure.json: sets up the adds-vnet, vpn gateway and the connection between the onpremise and azure vnets, creates adds-vm1 and adds-vm2 VMs, runs the azure.ps1 on both that VMs.