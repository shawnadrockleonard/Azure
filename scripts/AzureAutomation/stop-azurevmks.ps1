workflow Stop-WKAzureVMs
{   
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$VmStackConnName
    )
    
    $VerbosePreference=”Continue”

    # Connect to Azure Subscription
    Connect-AzureSubscription
        
    $jsonstack = Get-AutomationVariable -Name $VmStackConnName
    Write-Verbose "Variable from automation $VmStackConnName"
    
    $jsonobjects = $jsonstack | ConvertFrom-Json 


    inlineScript {
        $jsonobjects = $using:jsonobjects

        Write-Output "In the script searching for azure vms"

        $jsonobjects | Sort-Object { $_.shutorder } | ForEach-Object {
        Write-Verbose ("Now Stopping ServiceName {0} `t`tVirtualMachine {1}" -f $_.ServiceName, $_.ComputerName)
        
            do
            {
                $switch=$true
                $vm = Get-AzureVM -ServiceName $_.ServiceName -Name $_.ComputerName
                Write-Output ("Instance {0} is in state {1}" -f $vm.Name, $vm.Status )
                if ($vm.Status -eq 'ReadyRole' -or $vm.Status -ne "StoppedDeallocated" ) {
                    Write-Output ("{0} is ready to be shutdown" -f $vm.ServiceName)
                    $vm | Stop-AzureVM -Force    
                }
                
                if ($vm.Status -ne "StoppedDeallocated")
                {
                    $switch=$false
                }
                
                if (-Not($switch))
                {
                    Write-Verbose ("Waiting Azure Shutdown, it status is {0}" -f $vm.Status)
                    Start-Sleep -s 10
                }
            }
            until ($switch)  
        }                
    }
}