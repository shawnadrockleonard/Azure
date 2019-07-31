add-azurermaccount -Environment AzureUSGovernment
$rgroup = Get-AzureRmResourceGroup -Name "armcontoso-va"

$publicIP = New-AzureRmPublicIpAddress -ResourceGroupName armcontoso-va -Location usgovvirginia -Name "splwin10-sqlep" -AllocationMethod Dynamic -DomainNameLabel "splclientsql" 
$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name "splclientSqlEndFront" -PublicIpAddress $publicIP
$backendPool = New-AzureRmLoadBalancerBackendAddressPoolConfig  -Name "splclientSqlEndBack"

$probe = New-AzureRmLoadBalancerProbeConfig `
    -Name "splclientSqlHealthProbe" -Protocol Tcp -Port 59999 -IntervalInSeconds 16 -ProbeCount 2

$lbrule = New-AzureRmLoadBalancerRuleConfig `
    -Name "splclientSqlLbRule" -FrontendIpConfiguration $frontendIP -BackendAddressPool $backendPool -Protocol Tcp -FrontendPort 59999 -BackendPort 59999 -Probe $probe

$natrule1 = New-AzureRmLoadBalancerInboundNatRuleConfig `
    -Name 'splclientSqlLbRulePort' -FrontendIpConfiguration $frontendIP -Protocol tcp -FrontendPort 11433 -BackendPort 1433

$lb = New-AzureRmLoadBalancer `
    -Name 'splclientSqlLb' -ResourceGroupName armcontoso-va -Location 'USGov Virginia' -FrontendIpConfiguration $frontendIP -BackendAddressPool $backendPool -Probe $probe -LoadBalancingRule $lbrule -InboundNatRule $natrule1

$vm = get-azurermvm -ResourceGroupName armcontoso-va -Name "splwin10"
$vm | Stop-AzureRmVM
$vm.NetworkProfile.NetworkInterfaces[0].Primary = $true
$vm | Update-AzureRmVM

$rule1 = New-AzureRmNetworkSecurityRuleConfig `
    -Name 'splwin10-nsg-02-sql-rule-01' `
    -Description 'SQLPort' `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 310 `
    -SourceAddressPrefix 71.205.26.98 `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 1433


$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName armcontoso-va -Location 'USGov Virginia' -Name 'splwin10-nsg-02-sql' -SecurityRules $rule1

$vnet = Get-AzureRmVirtualNetwork -Name "armcontoso-va-01-vnet" -ResourceGroupName armcontoso-va
$vnetsubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "armcontoso-va-01-vnet-01-subnet" -VirtualNetwork $vnet

$nicVM1 = New-AzureRmNetworkInterface `
    -ResourceGroupName armcontoso-va `
    -Location 'USGov Virginia' -Name 'splclientSqlNic02' -LoadBalancerBackendAddressPool $backendPool `
    -NetworkSecurityGroup $nsg -LoadBalancerInboundNatRule $natrule1 -Subnet $vnetsubnet

Add-AzureRmVMNetworkInterface -VM $vm -Id $nicVM1.Id | Update-AzureRmVM -ResourceGroupName armcontoso-va