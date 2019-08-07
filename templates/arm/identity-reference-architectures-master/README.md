# Reference architectures for extending your Active Directory environment to Azure

For guidance see the article [Choose a solution for integrating on-premises Active Directory with Azure](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/identity/).

For each option, a more detailed reference architecture is available.

## AD DS in Azure joined to an on-premises forest

Deploy AD Domain Services (AD DS) servers to Azure. Create a domain in Azure and join it to your on-premises AD forest. 

[See the reference architecture](./adds-extend-domain/)

## AD DS in Azure with a separate forest

Deploy AD Domain Services (AD DS) servers to Azure, but create a separate Active Directory [forest][ad-forest-defn] that is separate from the on-premises forest. This forest is trusted by domains in your on-premises forest.

[See the reference architecture](./adds-forest/)

## Extend AD FS to Azure

Replicate an Active Directory Federation Services (AD FS) deployment to Azure, to perform federated authentication and authorization for components running in Azure. 

[See the reference architecture](./adfs/)

## Integrate your on-premises domains with Azure AD

Use Azure Active Directory (Azure AD) to create a domain in Azure and link it to an on-premises AD domain. 

[See the reference architecture](./azure-ad/)
