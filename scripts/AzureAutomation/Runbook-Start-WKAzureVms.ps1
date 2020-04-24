workflow Start-Vms
{
    Param
    (   
        [Parameter(Mandatory=$true)]
        [String]$VmStackConnName,
        
        [Parameter(Mandatory=$false)]
        [Bool]$vmWeekly 
    )
    
    $VerbosePreference=”Continue”

    # Connect to Azure Subscription
    Connect-AzureSubscription
        
    $jsonstack = Get-AutomationVariable -Name $VmStackConnName
    Write-Verbose "Variable from automation $VmStackConnName"
    
    $jsonobjects = $jsonstack | ConvertFrom-Json 

    inlineScript {
        $jsonobjects = $using:jsonobjects
        $jsonWeekly = $using:vmWeekly

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
                    if ($vm.Status -eq 'StoppedDeallocated' ) {
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
    }
}