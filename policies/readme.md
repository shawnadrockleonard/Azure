# Azure Subscription Management via DevOps

This is a readme to extend a fantastic [Blog](https://blog.tyang.org/2019/05/19/deploying-azure-policy-definitions-via-azure-devops-part-1/) with respect to validating and deploying Policies to Azure.    This will be an attempt to extend that discussion with Azure RBAC, DevOps (pipelines), DevOps (Artifacts), and GitHub integrations.

A few of the topics we will cover:

- **Azure Roles Based Access Controls:** RBAC ensures users and automated accounts mainain least privilege ***only the minimum access necessary to perform an operation should be granted***
- **Azure Resource Manager Templates for Policy:** Azure policies ensure your Az resources adhere to corporate/agency standards.
- **Azure Dev Ops:** pipelines (Build, Release) enable continuous development, validation, integration, and deployment
- **GitHub:** yaml, source code, and documentation. We'll then integrate with DevOps for full lifecycle
- **Azure:** review Azure pre and post deployment, compliance, and resources.  

## Tutorials you'll find interesting

I don't believe I should cover any of these topics in this readme.  I highly recommend you read these either before or after you follow the steps I outline as we'll cover these topics.

### Security | RBAC

Least privilege is an important topic.  You can assign individual policies to users or service principals but I've found the most effective approach is management groups.  Then assign users, groups, service principals to the mgmt groups.  Assign roles to the mgmt groups and you have an effective way of maintaining and reviewing access across the platform.  Read these links to understand this terminology.

- [Quickstart: Create a management group](https://docs.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal)
- [Organizing resources / hierarchy](https://docs.microsoft.com/en-us/azure/governance/management-groups/overview#hierarchy-of-management-groups-and-subscriptions)
- [Resource Policy Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#resource-policy-contributor)
  ***Note: Resource Policy Contributor is required for our DevOps release success***

### Policies

Policy Definitions and Assignments are a fantastic way to ensure your Az Subscriptions are well maintained.  Included in this Github repo are a number of policy definitions.  However, understanding what you can do and should do with policies can be found in these links.

- [Azure Policy built-in policy definitions](https://docs.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies)
- [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure)
- [Tutorial: Create and manage policies to enforce compliance](https://docs.microsoft.com/en-us/azure/governance/policy/tutorials/create-and-manage)
- [Tutorial: Manage tag governance with Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/tutorials/govern-tags)
- [Open source policy definitions on GitHub](https://github.com/Azure/azure-policy)

### Build GitHub repositories

We will build github repositories in a DevOps pipeline.  I'll take a few screenshots but for a more in depth outline take a peek at this detail.

- [Build GitHub repositories](https://docs.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml)

&nbsp;

## Let's get started

I'll break this into 7 parts.  At the end of the series you'll be able to use a full suite of products to ensure compliance and policies in your Azure environment.  You'll keep source code in GitHub in a public or private repository enabling hundreds of developers to participate.  You'll ensure the integrity of your policy definitions and ARM templates.  You'll have automated deployment into Azure or a gated deployment enabling a final approver to deploy the resulting builds.

- Step 01: Azure Artifacts
- Step 02: Service Principals
- Step 03: Azure Key Vault
- Step 04: Azure DevOps (Build)
  - Classic Pipeline
  - YAML pipeline
- Step 05: Azure DevOps (Release)
- Step 06: Azure Policies & Compliance reporting

&nbsp;

### Step 01: Azure Artifacts

[Azure Artifacts Overview [External]](https://azure.microsoft.com/en-us/services/devops/artifacts/)  

Create and share Maven, npm, NuGet, and Python package feeds from public and private sources.  This is important.  We are going to use a user generated powershell module 'AzTestPolicy'.   Follow this step by step process to create an Artifact feed and publish a powershell module in the nuget feed.

[Azure Artifacts Walkthrough](./README_part01.md)

&nbsp;

### Step 02: Service Principals

We will use Service Principals to connect Azure DevOps with Azure.  You can, when using Azure Public or Azure Commercial, walk through a Service Principal connection wizard.  We are going to walk through the steps manually so you understand what is happening.

I've included a helpful script to generate a SPN in Azure and assign it an initial RBAC authorization.
You can find a walkthrough of the script and Azure details here: [Walkthrough](./readme_part02.md)

&nbsp;

### Step 03: Azure Key Vault

While many teams / organizations will place their secrets in Build / Release pipelines I find this very frustrating in terms of policies.  

- Do the teams keep the secrets in plain text?  
- Do the teams have to replicate these variables across many pipelines?
- When a key changes, how does the development team receive a notification?
- What is the rotation policy on any of those secrets?

To address this issue I highly recommend variable groups and integration with a Key Vault.
You can find a walkthrough of the Azure Key Vault configuration here: [Walkthrough](./readme_part03.md)

&nbsp;

### Step 04: Azure DevOps Build Pipeline (***Classic***)

Build pipelines can be everything and anything.  You can have your build pipeline also deploy your artifacts.  For this step we are going to create a Classic UI pipeline to walk through the various components.  

You can find a walkthrough of the configuration here: [Walkthrough](./readme_part04_v01.md)

&nbsp;

### Step 04: Azure DevOps Build Pipeline (***YAML***)

Build pipelines can be everything and anything.  You can have your build pipeline also deploy your artifacts.  For this step we are going to leverage a YAML build definition to ensure our pipeline can be easily changed and its definition can be wrapped in source control.  This provide many benefits not to mention audit history, which item was changed and easy change history, and compliance based injection.  

You can find a walkthrough of the configuration here: [Walkthrough](./readme_part04_v02.md)

&nbsp;

### Step 05: Azure DevOps Release Pipeline (with gated deployment)

Release pipelines may not be what every developer advocates.  They may prefer to put 'Continous Deployment' in the YAML file.  However, Azure Releases have tremendous power to include authorization, validation, workflow, status, build retention, and issue tracking all out of the box (OOTB).

You can find a walkthrough of the configuration here: [Walkthrough](./readme_part05.md)

&nbsp;

### Step 06: Review Azure deployment and compliance

Azure is powerful.  You can enable workflows and concepts that were unphatomable a decade ago.  With that power and capability comes waste and an unscripted usage of resources.  Every organization has the power to assist developers while maintaining structure, compliance, and order.  With Policies you can claim the best of both worlds.  

You can find an overview of the Azure portal policy and compliance reviews.  We'll even show a resource that is Non-Compliant and how to fix it: [Walkthrough](./readme_part06.md)

&nbsp;

## Summary

I hope you've enjoyed this multi series walk through.  I cut out a number of items in this series.  If you have any issues with it or want me to address another series of items please feel free to create a Git Issue in this repository.

Sincerely,
Shawn Leonard
