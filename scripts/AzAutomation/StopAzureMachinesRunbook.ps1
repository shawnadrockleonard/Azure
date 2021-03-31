$VerbosePreference = ”Continue”

# Set Variables
$automationSubscription = "MyUltimateMSDN"
$automationAccountName = "splautomsdn"
$automationVariableName = "vms-dev"
$params = @{ vmStackConnName = $automationVariableName }

# Connect to Azure Subscription
.\connect-subscription.ps1 -subscriptionName $automationSubscription


$jobid = Start-AzureAutomationRunbook -Name "Stop-wkazurevms" -AutomationAccountName $automationAccountName -Parameters $params

do
{
    $switch = $true
    $vm = Get-AzureAutomationJob -Id $jobid.Id -AutomationAccountName $automationAccountName
    Write-Verbose ("Instance {0} is in state {1} check at {2}" -f $vm.RunbookName, $vm.Status, $vm.LastStatusModifiedTime)
                
    if ($vm.Status -ne "Completed")
    {
        $switch = $false
        Get-AzureAutomationJobOutput -Id $jobid.Id -AutomationAccountName $automationAccountName -Stream Any
    }
                
    if (-Not($switch))
    {
        Write-Verbose ("Waiting Azure runbook to complete {0}" -f $vm.Status)
        Start-Sleep -s 10
    }
}
until ($switch)         