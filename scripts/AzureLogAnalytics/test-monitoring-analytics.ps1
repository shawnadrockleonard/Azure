<#
    .SYNOPSIS
        Interogate Azure Log Analytics
#>
[CmdletBinding()]
Param(
    [ValidateSet("Azure", "AzureUSGovernment")]
    [Parameter(Mandatory = $true)] 
    [String]$environment,

    [Parameter(Mandatory = $true, HelpMessage = "resource group where log analytics exists.")] 
    [String]$resourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "specify if default subscription is not acting subscription.")] 
    [String]$subscriptionId,

    [Parameter(Mandatory = $true, HelpMessage = "specify the storage account from which metrics will be queried.")] 
    [String]$storageAccountName,

    # Password for the service principal
    [Parameter(Mandatory = $true)]
    [securestring]$AzureADSecret
)
BEGIN {


    #******************************************************************************
    # Script body
    # Execution begins here
    #******************************************************************************
    $AzModuleVersion = "2.8.0"

    # Verify that the Az module is installed 
    if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
        Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
        exit
    } 

    # Pulling current iteration of DSC module
    $DscWorkingFolder = $PSScriptRoot
    if (!(Test-Path ("{0}/monitoring" -f $DscWorkingFolder))) {
        New-Item -Path $DscWorkingFolder -Name "monitoring" -ItemType Directory
    }
    $JsonFolder = Join-Path -Path $DscWorkingFolder -ChildPath "monitoring" -Resolve

    $subscriptions = Get-AzSubscription -ErrorAction:SilentlyContinue
    if ($null -eq $subscriptions -or (($subscriptions | Where-Object Id -ne $subscriptionId) | Measure-Object).Count -le 0) {
        Connect-AzAccount -Environment $environment 
    }
}
PROCESS {

    $logAnalyticsRG = Get-AzResourceGroup -Name $resourceGroupName
    


    # Authenticate to a specific Azure subscription.
    $azureAdApplication = Get-AzADApplication -IdentifierUri "http://VSTS.shawn.leonard.371892d9-3fc6-4a89-bf86-3b0e646b5bae"

    $subscription = Get-AzSubscription -SubscriptionId $subscriptionId

    $clientId = $azureAdApplication.ApplicationId.Guid
    $tenantId = $subscription.TenantId
    $authUrl = "https://login.microsoftonline.us/${tenantId}"

    $AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]$authUrl
    $psCred = New-Object System.Management.Automation.PSCredential($clientId, $AzureADSecret)
    $cred = New-Object -TypeName Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential -ArgumentList ($clientId, ($psCred.GetNetworkCredential()).Password)

    $result = $AuthContext.AcquireTokenAsync("https://management.usgovcloudapi.net/", $cred).GetAwaiter().GetResult()

    # Build an array of HTTP header values
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
        'Authorization' = $result.CreateAuthorizationHeader()
    }

    $urlstorage = ("{0}/providers/Microsoft.Storage/storageAccounts/{1}" -f $logAnalyticsRG.ResourceId, $storageAccountName)


    Invoke-RestMethod -Uri ("https://management.usgovcloudapi.net/{0}/providers/microsoft.insights/metricDefinitions?api-version=2016-03-01" -f $urlstorage) `
        -Headers $authHeader `
        -Method Get `
        -OutFile ("{0}/metricdef-results.json" -f $JsonFolder) `
        -Verbose

    $filter = "(name.value eq 'UsedCapacity') and aggregationType eq 'Average'  and startTime eq 2019-05-20T19:00:00 and endTime eq 2019-05-31T23:00:00 and timeGrain eq duration'PT1H'"
    $filter = "timespan=2019-05-25T00:00:00Z/2019-06-01T00:00:00Z&interval=PT1H&metricnames=UsedCapacity&aggregation=Average"
    $filter = "timespan=2019-05-25T00:00:00Z/2019-06-01T00:00:00Z&interval=PT1H&metricnames=Transactions&aggregation=Total"
    Invoke-RestMethod -Uri ("https://management.usgovcloudapi.net/{0}/providers/microsoft.insights/metrics?{1}&api-version=2018-01-01" -f $urlstorage, $filter) `
        -Headers $authHeader `
        -Method Get `
        -OutFile ("{0}/metricdef-storage.json" -f $JsonFolder) `
        -Verbose

    $ruleid = ("https://management.usgovcloudapi.net/subscriptions/{0}/providers/microsoft.insights/actionGroups?api-version=2017-04-01" -f $subscription.SubscriptionId)
    Invoke-RestMethod -Uri $ruleid -Headers $authHeader -Method Get -Verbose -OutFile ("{0}/actiongroups.json" -f $JsonFolder)

    $rulesubscribe = ("https://management.usgovcloudapi.net/{0}/providers/microsoft.insights/actionGroups/all%20in%20the%20family/subscribe?api-version=2017-04-01" -f $logAnalyticsRG.ResourceId)
    Invoke-RestMethod -Uri $rulesubscribe -Headers $authHeader -Method Post -Body '{"receiverName":"coolbridge"}' -Verbose

}