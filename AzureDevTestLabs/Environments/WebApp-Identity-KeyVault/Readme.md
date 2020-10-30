# Azure Web App, KeyVault, Storage, SQL Server with Managed identity

Azure Web Apps enable you to build and host web applications in the programming language of your choice without managing infrastructure. It offers auto-scaling and high availability and enable automated deployments from [GitHub](https://github.com), [Azure DevOps](https://azure.microsoft.com/en-ca/services/devops), or any Git repo.

To learn more about Web Apps refer to [App Service overview](https://docs.microsoft.com/en-us/azure/app-service/overview) documentation.

This template allows you to create a Web App with SQL.


## Deploy Environment outside of DevTest Labs

This template allows you to create 
- A storage account preset with Static Website container
- A KeyVault.  
- A Log Analytics workspace
- An Application Insights instance using the Log Analytics workspace
- An App Service Plan
- An App Service
- A SQL Server 
- A Basic database in the SQL Server instance
This will enable enable managed identity with KeyVault policies.
This will add KeyVault entries based on the supplied ARM Template parameters


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2FAzureDevTestLabs%2FEnvironments%2FWebApp-Identity-KeyVault%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/metadata/deploytoazure.png"/> 
</a>


<a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2FAzureDevTestLabs%2FEnvironments%2FWebApp-Identity-KeyVault%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/metadata/deploytoazuregov.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fshawnadrockleonard%2FAzure%2Fshawns%2Fdotnetcore%2FAzureDevTestLabs%2FEnvironments%2FWebApp-Identity-KeyVault%2F2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/shawnadrockleonard/Azure/shawns/dotnetcore/templates/metadata/visualizebutton.png"/> 
</a>