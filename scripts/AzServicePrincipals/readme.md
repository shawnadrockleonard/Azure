# Azure Service Principals

Azure service principals (SPNs) are intregral to many deployments and management scenarios for Azure.  
This particular scriptlet is designed to automate the creation of an SPN for Azure DevOps.  
*However, this scriptlet can be used to create any SPN for future use.*

[[_TOC_]]


## Executing the script

```powershell
.\scripts\create-azuread-svc-principal.ps1

# Copy and Paste below values for Service Connection
# ***************************************************************************
Connection Name: (SPN)
Environment:
Subscription Id:
Subscription Name:
Service Principal Id:
Service Principal key: <Password that you typed in>
Tenant Id:
# ***************************************************************************
```

## Azure DevOps Labs

A conveniently published series of screenshots is available on DevOps Labs
[https://azuredevopslabs.com/labs/devopsserver/azureserviceprincipal/](Azure DevOps Service Principal)

## Azure DevOps Manual configuration

For Azure Government, Azure Germany, Azure China you'll need to connect a service connection via Manual steps.  
Included below are the steps to connect your new SPN.

### Screenshots for connecting the SPN in Az DevOps 'Service Connections'

1; Create service connection

- ![Step 01](./docs/spn04.png)

2; Choose connection type 'Azure Resource Manager'

- ![Step 02](./docs/spn05.png)

3; \*\*\* if this is NOT Azure Commercial; choose `Service Principal (manual)`

- ![Step 03](./docs/spn06.png)

4; Enter service connection details from the powershell script output **_Ex: Azure Government_** then click Verify

- ![Step 04](./docs/spn07.png)

5; Enter a name for your service connection

- ![Step 05](./docs/spn08.png)

6; Service connections list

- ![Step 06](./docs/spn09.png)