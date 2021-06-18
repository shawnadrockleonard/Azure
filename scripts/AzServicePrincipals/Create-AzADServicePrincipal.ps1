<#
.DESCRIPTION
    Create a Service Principal

.EXAMPLE
    $securepassword = ConvertTo-SecureString -String "<a secure password>" -AsPlainText -Force 
    .\scripts\AzServicePrincipals\Create-AzADServicePrincipal.ps1 `
        -subscriptionName "SPL-MAG-AIRS" `
        -password $securepassword `
        -spnRole contributor `
        -environmentName AzureUSGovernment `
        -Verbose    

#>
[CmdLetBinding(SupportsShouldProcess = $true)]
Param
(
    [Parameter(Mandatory = $true, HelpMessage = "Enter Azure Subscription name. You need to be Subscription Admin to execute the script")]
    [string] $subscriptionName,

    [Parameter(Mandatory = $true, HelpMessage = "Provide a password for SPN application that you would create; this becomes the service principal's security key")]
    [securestring] $password,

    [ValidateSet("owner", "contributor", "reader")]
    [Parameter(Mandatory = $false, HelpMessage = "Provide a SPN role assignment")]
    [string] $spnRole = "owner",
   
    [ValidateSet("AzureUSGovernment", "Azure")]
    [Parameter(Mandatory = $false, HelpMessage = "Provide Azure environment name for your subscription")]
    [string] $environmentName = "AzureUSGovernment"
)
BEGIN
{
    #Initialize
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "SilentlyContinue"
    $userName = ($env:USERNAME).Replace(' ', '')
}
PROCESS
{

    function Get-AzureCmdletsVersion
    {
        [CmdLetBinding()]
        param()
        process
        {
            $module = Get-Module Az -ListAvailable
            if ($module)
            {
                return ($module).Version
            }
            return (Get-Module Az -ListAvailable).Version
        }
    }

    function Get-Password
    {
        [CmdLetBinding()]
        param([securestring] $securepassword)
        process
        {
            $currentAzurePSVersion = Get-AzureCmdletsVersion
            $azureVersion511 = New-Object System.Version(5, 1, 1)
            if ($currentAzurePSVersion -and $currentAzurePSVersion -ge $azureVersion511)
            {
                $plainPassword = ConvertFrom-SecureString -SecureString $securepassword -AsPlainText
                return $plainPassword
            }
            else
            {
                $basicPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securepassword)
                $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($basicPassword)
                return $plainPassword
            }
        }
    }


    #Initialize subscription
    $isAzureModulePresent = Get-Module -Name Az* -ListAvailable
    if ([String]::IsNullOrEmpty($isAzureModulePresent) -eq $true)
    {
        Write-Output "Script requires Az modules to be present. Obtain AzureRM from https://github.com/Azure/azure-powershell/releases. Please refer https://github.com/Microsoft/vsts-tasks/blob/master/Tasks/DeployAzureResourceGroup/README.md for recommended Az versions." -Verbose
        return
    }

    Import-Module -Name Az.Accounts

    $context = Get-AzContext
    if ($null -eq $context -or $context.Subscription.Name -ne $subscriptionName)
    {
        Write-Output "Provide your credentials to access Azure subscription $subscriptionName" -Verbose
        Add-AzAccount -SubscriptionName $subscriptionName -EnvironmentName $environmentName -UseDeviceAuthentication
    }

    $context = Get-AzContext
    $azureSubscription = Get-AzSubscription -SubscriptionName $subscriptionName
    $connectionName = $azureSubscription.Name
    $tenantId = $azureSubscription.TenantId
    $id = $azureSubscription.SubscriptionId

    $accountId = $context.Account
    $userObject = $accountId -split '@'
    $userName = $userObject[0]

    #dynamic variables
    $newguid = [guid]::NewGuid()
    $displayName = [String]::Format("AzDevOps.{0}.{1}", $userName, $newguid)
    $homePage = "https://" + $displayName
    $identifierUri = $homePage


    #Create a new AD Application
    Write-Output "Creating a new Application in AAD (App URI - $identifierUri)" -Verbose
    $azureAdApplication = New-AzADApplication -DisplayName $displayName -HomePage $homePage -IdentifierUris $identifierUri -Password $password -Verbose
    $appId = $azureAdApplication.ApplicationId
    Write-Output "Azure AAD Application creation completed successfully (Application Id: $appId)" -Verbose

    #Create new SPN
    Write-Output "Creating a new SPN" -Verbose
    $spn = New-AzADServicePrincipal -ApplicationId $appId
    $spnName = $spn.ServicePrincipalName
    Write-Output "SPN creation completed successfully (SPN Name: $spnName)" -Verbose

    #Assign role to SPN
    Write-Output "Waiting for SPN creation to reflect in Directory before Role assignment"
    Start-Sleep 20
    Write-Output "Assigning role ($spnRole) to SPN App ($appId)" -Verbose
    New-AzRoleAssignment -RoleDefinitionName $spnRole -ServicePrincipalName $appId -ErrorAction SilentlyContinue
    Write-Output "SPN role assignment completed successfully" -Verbose
  
    #Print the values
    Write-Output "`nCopy and Paste below values for Service Connection" -Verbose
    Write-Output "***************************************************************************"
    Write-Output "Connection Name: $connectionName(SPN)"
    Write-Output "Environment: $environmentName"
    Write-Output "Subscription Id: $id"
    Write-Output "Subscription Name: $connectionName"
    Write-Output "Service Principal Id: $appId"
    Write-Output "Service Principal key: <Password that you typed in>"
    Write-Output "Tenant Id: $tenantId"
    Write-Output "***************************************************************************"

}