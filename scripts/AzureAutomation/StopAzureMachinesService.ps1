$VerbosePreference=”Continue”

# Set Variables
    $automationSubscription = "MyUltimateMSDN"
    $automationAccountName = "splautomsdn"
    $automationVariableName = "vms-dev"
    $params = @{ vmStackConnName=$automationVariableName }

# Connect to Azure Subscription
    .\connect-subscription.ps1 -subscriptionName $automationSubscription


    Write-Verbose ("The script will shut down machines for {0}" -f $automationVariableName)
    $jsonstack = Get-AzureAutomationVariable -Name $automationVariableName -AutomationAccountName $automationAccountName
    $jsonobjects = $jsonstack.Value | ConvertFrom-Json 
         
$jsonobjects | Sort-Object { $_.shutorder } | ForEach-Object {
    Write-Verbose ("Now Shutting down ServiceName {0} `t`tVirtualMachine {1}" -f $_.ServiceName, $_.ComputerName)
            
    do
    {
        $switch=$true
        $vm = Get-AzureVM -ServiceName $_.ServiceName -Name $_.ComputerName
        Write-Verbose ("Instance {0} is in state {1}" -f $vm.Name, $vm.Status )
        if ($vm.Status -ne 'StoppedDeallocated') {
            Write-Verbose ("{0} is ready to shutdown" -f $vm.ServiceName)
            $vm | Stop-AzureVM -Force
        }
                
        if ($vm.Status -ne "StoppedDeallocated")
        {
            $switch=$false
        }
                
        if (-Not($switch))
        {
            Write-Verbose ("Waiting Azure machine {0} with status" -f $vm.Name, $vm.Status)
            Start-Sleep -s 10
        }
    }
    until ($switch)           
}