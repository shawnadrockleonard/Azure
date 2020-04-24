$VerbosePreference=”Continue”

# Set Variables
    $automationSubscription = "MyUltimateMSDN"
    $automationAccountName = "splautomsdn"
    $automationVariableName = "vms-dev"
    $params = @{ vmStackConnName=$automationVariableName; vmWeekly=$true }

# Connect to Azure Subscription
    .\connect-subscription.ps1 -subscriptionName $automationSubscription

    $jsonstack = Get-AzureAutomationVariable -Name $automationVariableName -AutomationAccountName $automationAccountName
    Write-Verbose "Variable from automation $automationVariableName"
    
$jsonobjects = $jsonstack.Value | ConvertFrom-Json 


$vmStartUp = $true
if($jsonWeekly -eq $True) {
    $vmStartUp = $False
    $currentDay = (Get-Date).DayOfWeek
    If(($currentDay –gt 0) -and ($currentDay –lt 6)) {
        $vmStartUp = $true
    }
}

Write-Verbose ("The script will execute = {0}" -f $vmStartup)
if($vmStartUp) {
         
    $jsonobjects | Sort-Object { $_.startorder } | ForEach-Object {
        Write-Verbose ("Now Starting ServiceName {0} `t`tVirtualMachine {1}" -f $_.ServiceName, $_.ComputerName)
            
        do
        {
            $switch=$true
            $vm = Get-AzureVM -ServiceName $_.ServiceName -Name $_.ComputerName
            Write-Verbose ("Instance {0} is in state {1}" -f $vm.Name, $vm.Status )
            if ($vm.Status -eq 'StoppedDeallocated' -or $vm.Status -eq 'StoppedVM' ) {
                Write-Verbose ("{0} is ready to start" -f $vm.ServiceName)
                $vm | Start-AzureVM    
            }
                
            if ($vm.Status -ne "ReadyRole")
            {
                $switch=$false
            }
                
            if (-Not($switch))
            {
                Write-Verbose ("Waiting Azure Startup, it status is {0}" -f $vm.Status)
                Start-Sleep -s 10
            }
        }
        until ($switch)           
    }
}


    Get-AzureVm | Foreach-object {
        
        Write-Output ("VM:{0} is in State:{1}" -f $_.Name,$_.Status)           
    }
    
    Get-AzureStorageAccount | Foreach-Object {
        
        Write-Output ("Account:{0} is of type:{1}" -f $_.StorageAccountName,$_.AccountType)
    }