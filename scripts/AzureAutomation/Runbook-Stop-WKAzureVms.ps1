workflow Stop-WKAzureVMs
{   
    Param
    (
           [string]$hello
    )

    Write-Output ("connected to subscription {0} successfully" -f $hello)
    # Connect to Azure Subscription
        Connect-AzureSubscription

    inlineScript {

        Write-Output "In the script searching for azure vms"

        Get-AzureVM | %{
            
            Write-Output ("{0} server with status {1}" -f $_.Name,$_.Status)

            do
            {
                $switch=$true
                $vm = Get-AzureVM -ServiceName $_.ServiceName -Name $_.Name
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