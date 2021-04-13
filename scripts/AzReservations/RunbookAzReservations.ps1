<#
    .DESCRIPTION
        A runbook which gets all reservations, sets permissions, uploads to AzStorage
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