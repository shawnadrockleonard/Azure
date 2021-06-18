# Azure Service Principals

Azure service principals (SPNs) are intregral to many deployments and management scenarios for Azure.  
This particular scriptlet is designed to automate the creation of an SPN for Azure DevOps.  
*However, this scriptlet can be used to create any SPN for future use.*

[[_TOC_]]

## Executing the script

```powershell
# This will be your initial 'Secret' in the App Registration
$securepassword = ConvertTo-SecureString -String "<a secure password>" -AsPlainText -Force 

# Executing the scriptlet from the command line
.\scripts\AzServicePrincipals\Create-AzADServicePrincipal.ps1 `
    -subscriptionName "<Your Az Subscription Name>" `
    -password $securepassword `
    -spnRole contributor `  # Will associate the Role in Azure to the SPN
    -environmentName AzureUSGovernment ` # Default is Commercial
    -Verbose  # Increased log output

# The execution will emit the following:
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

```powershell
# Query Azure AD

# Note: The script will create an application with the naming convention 'AzDevOps.{0}.{1}' 0 = Username; 1 = Guid.New
Get-AzAdApplication -DisplayNameStartWith "AzDevOps."
```

&nbsp;

## Result of the script

After you run the scriptlet you'll have a new "Enterprise App" in Azure.  The output of the scriptlet "Service Principal Id" is the "Application ID".  This value will be used in the manual configuration for the "Service Principal Id".  The output of the create svc principal scriptlet will be 1 application with 2 components (Enterprise Application and an App Registration)

