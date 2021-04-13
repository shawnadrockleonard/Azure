<#
.SYNOPSIS 
    Sets up the connection to an Azure subscription

.DESCRIPTION
	This runbook sets up a connection to an Azure subscription.
    Requirements: 
        1. Active Directory User with Service Administrator permissions
        2. Automation Connection for PS Credentials

.EXAMPLE
    Connect-Azure

.NOTES
    AUTHOR: shawn Leonard
    LASTEDIT: Jan 5, 2015
#>
workflow Connect-AzureSubscription
{
    Param
    (        
    )

    # Get the Azure connection asset that is stored in the Auotmation service based on the name that was passed into the runbook 
    $AzureConn = Get-AutomationPSCredential -name "psauto"
    if ($AzureConn -eq $null)
    {
        throw "Could not retrieve '$AzureConn' connection asset."
    }


    $SubscriptionName = "MyUltimateMSDN"


    inlineScript {
        $AzureConn = $using:AzureConn
        $SubscriptionName = $using:SubscriptionName  
        
    # Get the Azure management certificate that is used to connect to this subscription
        Add-AzureAccount -Credential $AzureConn #| Out-Null
        Select-AzureSubscription -SubscriptionName $SubscriptionName | Out-Null
        Write-Output "Successfully connected to the subscription."
    }
}