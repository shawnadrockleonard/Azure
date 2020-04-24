<#
    Author: Shawn Leonard sleonard@microsoft.com

    This is an example provided as is and is not meant for use on a
    production environment. It is provided only for illustrative
    purposes. The end user must test and modify the sample to suit
    their target environment.

    Microsoft can make no representation concerning the content of
    this sample. Microsoft is providing this information only as a
    convenience to you. This is to inform you that Microsoft has not
    tested the sample and therefore cannot make any representations
    regarding the quality, safety, or suitability of any code or
    information found here. 
#>
workflow connect-RBSubscription
{
    
    $VerbosePreference=”Continue”

    # Set Azure EndPoints    
    if (!(Get-AzureEnvironment -Name "AzureGovernmentCloud")) {
        Write-Output "`r`nAdding AzureGovernmentCloud Environment"
        
        Add-AzureEnvironment -Name "AzureGovernmentCloud" `
        -PublishSettingsFileUrl "https://manage.windowsazure.us/publishsettings/index" `
        -ServiceEndpoint "https://management.core.usgovcloudapi.net/" `
        -ManagementPortalUrl "https://manage.windowsazure.us/" `
        -ActiveDirectoryEndpoint "https://login.windows.net/" `
        -ActiveDirectoryServiceEndpointResourceId "https://management.core.usgovcloudapi.net/" `
        -StorageEndpoint "core.usgovcloudapi.net"
    }

    Write-Output "`r`nAzureGovernmentCloud Environment successfully added`r`n"
    Get-AzureEnvironment -Name "AzureGovernmentCloud"

    # Get the Azure connection asset that is stored in the Auotmation service based on the name that was passed into the runbook 
    $AzureConn = Get-AutomationPSCredential -name "mycreds"
    if ($AzureConn -eq $null)
    {
        throw "Could not retrieve '$AzureConn' connection asset."
    }

    $SubscriptionName = Get-AutomationVariable -Name "mysubscription"
    Write-Output ("{0} subscription name" -f $SubscriptionName)
    
    inlineScript {
        $AzureConn = $using:AzureConn
        $SubscriptionName = $using:SubscriptionName  
        
    # Get the Azure management certificate that is used to connect to this subscription
        Add-AzureAccount -Environment "AzureGovernmentCloud" -Credential $AzureConn #| Out-Null
        Select-AzureSubscription -SubscriptionName $SubscriptionName | Out-Null
        Write-Output "Successfully connected to the subscription."
    }    
    
}