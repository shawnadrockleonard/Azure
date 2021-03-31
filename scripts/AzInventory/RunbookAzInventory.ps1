<#
    .DESCRIPTION
        A runbook to retreive all resources in the subscription
#>

$connectionName = "AzureRunAsConnection"
try
{
    Import-Module Az.Accounts -MinimumVersion 2.2.6
    Import-module Az.Resources -MinimumVersion 3.3.0


    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -Environment AzureUSGovernment
}
catch
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Get all ARM resources from all resource groups
$ResourceGroups = Get-AzResourceGroup | select-object ResourceGroupName, Location

foreach ($ResourceGroup in $ResourceGroups)
{    
    Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
    $Resources = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName | Select-Object ResourceName, ResourceType
    ForEach ($Resource in $Resources)
    {
        Write-Output ($Resource.ResourceName + " of type " + $Resource.ResourceType)
    }
    Write-Output ("")
} 
