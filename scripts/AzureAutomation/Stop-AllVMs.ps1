workflow Stop-AllVMs {
    # Specify Azure Subscription Name
    $subName = '[YOUR-AZURE-SUBSCRIPTION-NAME]'
    
    # Connect to Azure Subscription
    Connect-Azure `
        -AzureConnectionName $subName
        
    Select-AzureSubscription `
        -SubscriptionName $subName 
        
       
    Write-output "Starting shutdown of Azure VMs now!"
    
    Get-AzureService | select ServiceName | foreach { 
        Get-AzureVM -ServiceName $_.ServiceName | foreach {
            if ($_.InstanceStatus -eq 'ReadyRole') {
         
                $currentTime = Get-Date
                $vmName = $_.Name
                $svcName = $_.ServiceName
                Write-output "[$currentTime] -  Shutting down VM [$vmName] in service [$svcName]."
         
                Stop-AzureVM -ServiceName $_.ServiceName -Name $_.Name -Force
            }
        }
    }

}