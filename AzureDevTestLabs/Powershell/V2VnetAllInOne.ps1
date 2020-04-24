function ReadHostWithDefault($message, $default) {
    $result = Read-Host "$message [$default]"
    if ($result -eq "") {
        $result = $default
    }
    return $result
}

function PromptCustom($title, $optionValues, $optionDescriptions) {
    Write-Host $title
    Write-Host
    $a = @()
    for ($i = 0; $i -lt $optionValues.Length; $i++) {
        Write-Host "$($i+1))" $optionDescriptions[$i]
    }
    Write-Host

    while ($true) {
        Write-Host "Choose an option: "
        $option = Read-Host
        $option = $option -as [int]

        if ($option -ge 1 -and $option -le $optionValues.Length) {
            return $optionValues[$option - 1]
        }
    }
}

function PromptYesNo($title, $message, $default = 0) {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", ""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", ""
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $result = $host.ui.PromptForChoice($title, $message, $options, $default)
    return $result
}

function CreateVnet($resourceGroupName, $vnetName, $vnetAddressSpace, $vnetGatewayAddressSpace, $location) {
    Write-Host "Creating a new VNET"
    $gatewaySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $vnetGatewayAddressSpace
    New-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressSpace -Subnet $gatewaySubnet
}

function CreateVnetGateway($resourceGroupName, $vnetName, $vnetIpName, $location, $vnetIpConfigName, $vnetGatewayName, $certificateData, $vnetPointToSiteAddressSpace) {
    $vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

    Write-Host "Creating a public IP address for this VNET"
    $pip = New-AzureRmPublicIpAddress -Name $vnetIpName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic
    $ipconf = New-AzureRmVirtualNetworkGatewayIpConfig -Name $vnetIpConfigName -Subnet $subnet -PublicIpAddress $pip

    Write-Host "Adding a root certificate to this VNET"
    $root = New-AzureRmVpnClientRootCertificate -Name "AppServiceCertificate.cer" -PublicCertData $certificateData

    Write-Host "Creating Azure VNET Gateway. This may take up to an hour."
    New-AzureRmVirtualNetworkGateway -Name $vnetGatewayName -ResourceGroupName $resourceGroupName -Location $location -IpConfigurations $ipconf -GatewayType Vpn -VpnType RouteBased -EnableBgp $false -GatewaySku Basic -VpnClientAddressPool $vnetPointToSiteAddressSpace -VpnClientRootCertificates $root -VpnClientProtocol SSTP
}

function AddNewVnet($subscriptionId, $webAppResourceGroup, $webAppName) {
    Write-Host "Adding a new Vnet"
    Write-Host
    $vnetName = Read-Host "Specify a name for this Virtual Network"

    $vnetGatewayName = "$($vnetName)-gateway"
    $vnetIpName = "$($vnetName)-ip"
    $vnetIpConfigName = "$($vnetName)-ipconf"

    # Virtual Network settings
    $vnetAddressSpace = "10.0.0.0/8"
    $vnetGatewayAddressSpace = "10.5.0.0/16"
    $vnetPointToSiteAddressSpace = "172.16.0.0/16"

    $changeRequested = 0
    $resourceGroupName = $webAppResourceGroup

    while ($changeRequested -eq 0) {
        Write-Host
        Write-Host "Currently, I will create a VNET with the following settings:"
        Write-Host
        Write-Host "Virtual Network Name: $vnetName"
        Write-Host "Resource Group Name:  $resourceGroupName"
        Write-Host "Gateway Name: $vnetGatewayName"
        Write-Host "Vnet IP name: $vnetIpName"
        Write-Host "Vnet IP config name:  $vnetIpConfigName"
        Write-Host "Address Space:$vnetAddressSpace"
        Write-Host "Gateway Address Space:$vnetGatewayAddressSpace"
        Write-Host "Point-To-Site Address Space:  $vnetPointToSiteAddressSpace"
        Write-Host
        $changeRequested = PromptYesNo "" "Do you wish to change these settings?" 1

        if ($changeRequested -eq 0) {
            $vnetName = ReadHostWithDefault "Virtual Network Name" $vnetName
            $resourceGroupName = ReadHostWithDefault "Resource Group Name" $resourceGroupName
            $vnetGatewayName = ReadHostWithDefault "Vnet Gateway Name" $vnetGatewayName
            $vnetIpName = ReadHostWithDefault "Vnet IP name" $vnetIpName
            $vnetIpConfigName = ReadHostWithDefault "Vnet IP configuration name" $vnetIpConfigName
            $vnetAddressSpace = ReadHostWithDefault "Vnet Address Space" $vnetAddressSpace
            $vnetGatewayAddressSpace = ReadHostWithDefault "Vnet Gateway Address Space" $vnetGatewayAddressSpace
            $vnetPointToSiteAddressSpace = ReadHostWithDefault "Vnet Point-to-site Address Space" $vnetPointToSiteAddressSpace
        }
    }

    $ErrorActionPreference = "Stop";

    # We create the virtual network and add it here. The way this works is:
    # 1) Add the VNET association to the App. This allows the App to generate certificates, etc. for the VNET.
    # 2) Create the VNET and VNET gateway, add the certificates, create the public IP, etc., required for the gateway
    # 3) Get the VPN package from the gateway and pass it back to the App.

    $webApp = Get-AzureRmResource -ResourceName $webAppName -ResourceType "Microsoft.Web/sites" -ApiVersion 2015-08-01 -ResourceGroupName $webAppResourceGroup
    $location = $webApp.Location

    Write-Host "Creating App association to VNET"
    $propertiesObject = @{
        "vnetResourceId" = "/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.Network/virtualNetworks/$($vnetName)"
    }
    $virtualNetwork = New-AzureRmResource -Location $location -Properties $PropertiesObject -ResourceName "$($webAppName)/$($vnetName)" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections" -ApiVersion 2015-08-01 -ResourceGroupName $webAppResourceGroup -Force

    CreateVnet $resourceGroupName $vnetName $vnetAddressSpace $vnetGatewayAddressSpace $location

    CreateVnetGateway $resourceGroupName $vnetName $vnetIpName $location $vnetIpConfigName $vnetGatewayName $virtualNetwork.Properties.CertBlob $vnetPointToSiteAddressSpace

    Write-Host "Retrieving VPN Package and supplying to App"
    $packageUri = Get-AzureRmVpnClientPackage -ResourceGroupName $resourceGroupName -VirtualNetworkGatewayName $vnetGatewayName -ProcessorArchitecture Amd64
    
    # $packageUri may contain literal double-quotes at the start and the end of the URL
    if ($packageUri.Length -gt 0 -and $packageUri.Substring(0, 1) -eq '"' -and $packageUri.Substring($packageUri.Length - 1, 1) -eq '"') {
        $packageUri = $packageUri.Substring(1, $packageUri.Length - 2)
    }

    # Put the VPN client configuration package onto the App
    $PropertiesObject = @{
        "vnetName" = $VirtualNetworkName; "vpnPackageUri" = $packageUri
    }

    New-AzureRmResource -Location $location -Properties $PropertiesObject -ResourceName "$($webAppName)/$($vnetName)/primary" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections/gateways" -ApiVersion 2015-08-01 -ResourceGroupName $webAppResourceGroup -Force

    Write-Host "Finished!"
}

function AddExistingVnet($subscriptionId, $resourceGroupName, $webAppName) {
    $ErrorActionPreference = "Stop";

    # At this point, the gateway should be able to be joined to an App, but may require some minor tweaking. We will declare to the App now to use this VNET
    Write-Host "Getting App information"
    $webApp = Get-AzureRmResource -ResourceName $webAppName -ResourceType "Microsoft.Web/sites" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName
    $location = $webApp.Location

    $webAppConfig = Get-AzureRmResource -ResourceName "$($webAppName)/web" -ResourceType "Microsoft.Web/sites/config" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName
    $currentVnet = $webAppConfig.Properties.VnetName
    if ($currentVnet -ne $null -and $currentVnet -ne "") {
        Write-Host "Currently connected to VNET $currentVnet"
    }

    # Display existing vnets
    $vnets = Get-AzureRmVirtualNetwork
    $vnetNames = @()
    foreach ($vnet in $vnets) {
        $vnetNames += $vnet.Name
    }

    Write-Host
    $vnet = PromptCustom "Select a VNET to integrate with" $vnets $vnetNames

    # We need to check if this VNET is able to be joined to a App, based on following criteria
    # If there is no gateway, we can create one.
    # If there is a gateway:
    # It must be of type Vpn
    # It must be of VpnType RouteBased
    # If it doesn't have the right certificate, we will need to add it.
    # If it doesn't have a point-to-site range, we will need to add it.

    $gatewaySubnet = $vnet.Subnets | Where-Object { $_.Name -eq "GatewaySubnet" }

    if ($gatewaySubnet -eq $null -or $gatewaySubnet.IpConfigurations -eq $null -or $gatewaySubnet.IpConfigurations.Count -eq 0) {
        $ErrorActionPreference = "Continue";
        # There is no gateway. We need to create one.
        Write-Host "This Virtual Network has no gateway. I will need to create one."

        $vnetName = $vnet.Name
        $vnetGatewayName = "$($vnetName)-gateway"
        $vnetIpName = "$($vnetName)-ip"
        $vnetIpConfigName = "$($vnetName)-ipconf"

        # Virtual Network settings
        $vnetAddressSpace = "10.0.0.0/8"
        $vnetGatewayAddressSpace = "10.5.0.0/16"
        $vnetPointToSiteAddressSpace = "172.16.0.0/16"

        $changeRequested = 0

        Write-Host "Your VNET is in the address space $($vnet.AddressSpace.AddressPrefixes), with the following Subnets:"
        foreach ($subnet in $vnet.Subnets) {
            Write-Host "$($subnet.Name): $($subnet.AddressPrefix)"
        }

        $vnetGatewayAddressSpace = Read-Host "Please choose a GatewaySubnet address space"

        while ($changeRequested -eq 0) {
            Write-Host
            Write-Host "Currently, I will create a VNET gateway with the following settings:"
            Write-Host
            Write-Host "Virtual Network Name: $vnetName"
            Write-Host "Resource Group Name:  $($vnet.ResourceGroupName)"
            Write-Host "Gateway Name: $vnetGatewayName"
            Write-Host "Vnet IP name: $vnetIpName"
            Write-Host "Vnet IP config name:  $vnetIpConfigName"
            Write-Host "Address Space:$($vnet.AddressSpace.AddressPrefixes)"
            Write-Host "Gateway Address Space:$vnetGatewayAddressSpace"
            Write-Host "Point-To-Site Address Space:  $vnetPointToSiteAddressSpace"
            Write-Host
            $changeRequested = PromptYesNo "" "Do you wish to change these settings?" 1

            if ($changeRequested -eq 0) {
                $vnetGatewayName = ReadHostWithDefault "Vnet Gateway Name" $vnetGatewayName
                $vnetIpName = ReadHostWithDefault "Vnet IP name" $vnetIpName
                $vnetIpConfigName = ReadHostWithDefault "Vnet IP configuration name" $vnetIpConfigName
                $vnetGatewayAddressSpace = ReadHostWithDefault "Vnet Gateway Address Space" $vnetGatewayAddressSpace
                $vnetPointToSiteAddressSpace = ReadHostWithDefault "Vnet Point-to-site Address Space" $vnetPointToSiteAddressSpace
            }
        }

        $ErrorActionPreference = "Stop";

        Write-Host "Creating App association to VNET"
        $propertiesObject = @{
            "vnetResourceId" = "/subscriptions/$($subscriptionId)/resourceGroups/$($vnet.ResourceGroupName)/providers/Microsoft.Network/virtualNetworks/$($vnetName)"
        }

        $virtualNetwork = New-AzureRmResource -Location $location -Properties $PropertiesObject -ResourceName "$($webAppName)/$($vnet.Name)" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName -Force

        # If there is no gateway subnet, we need to create one.
        if ($gatewaySubnet -eq $null) {
            $gatewaySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $vnetGatewayAddressSpace
            $vnet.Subnets.Add($gatewaySubnet);
            Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
        }

        CreateVnetGateway $vnet.ResourceGroupName $vnetName $vnetIpName $location $vnetIpConfigName $vnetGatewayName $virtualNetwork.Properties.CertBlob $vnetPointToSiteAddressSpace

        $gateway = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $vnet.ResourceGroupName -Name $vnetGatewayName
    }
    else {
        $uriParts = $gatewaySubnet.IpConfigurations[0].Id.Split('/')
        $gatewayResourceGroup = $uriParts[4]
        $gatewayName = $uriParts[8]

        $gateway = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $vnet.ResourceGroupName -Name $gatewayName

        # validate gateway types, etc.
        if ($gateway.GatewayType -ne "Vpn") {
            Write-Error "This gateway is not of the Vpn type. It cannot be joined to an App."
            return
        }

        if ($gateway.VpnType -ne "RouteBased") {
            Write-Error "This gateways Vpn type is not RouteBased. It cannot be joined to an App."
            return
        }

        if ($gateway.VpnClientConfiguration -eq $null -or $gateway.VpnClientConfiguration.VpnClientAddressPool -eq $null) {
            Write-Host "This gateway does not have a Point-to-site Address Range. Please specify one in CIDR notation, e.g. 10.0.0.0/8"
            $pointToSiteAddress = Read-Host "Point-To-Site Address Space"
            Set-AzureRmVirtualNetworkGatewayVpnClientConfig -VirtualNetworkGateway $gateway.Name -VpnClientAddressPool $pointToSiteAddress
        }

        Write-Host "Creating App association to VNET"
        $propertiesObject = @{
            "vnetResourceId" = "/subscriptions/$($subscriptionId)/resourceGroups/$($vnet.ResourceGroupName)/providers/Microsoft.Network/virtualNetworks/$($vnet.Name)"
        }

        $virtualNetwork = New-AzureRmResource -Location $location -Properties $PropertiesObject -ResourceName "$($webAppName)/$($vnet.Name)" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName -Force

        # We need to check if the certificate here exists in the gateway.
        $certificates = $gateway.VpnClientConfiguration.VpnClientRootCertificates

        $certFound = $false
        foreach ($certificate in $certificates) {
            if ($certificate.PublicCertData -eq $virtualNetwork.Properties.CertBlob) {
                $certFound = $true
                break
            }
        }

        if (-not $certFound) {
            Write-Host "Adding certificate"
            Add-AzureRmVpnClientRootCertificate -VpnClientRootCertificateName "AppServiceCertificate.cer" -PublicCertData $virtualNetwork.Properties.CertBlob -VirtualNetworkGatewayName $gateway.Name
        }
    }

    # Now finish joining by getting the VPN package and giving it to the App
    Write-Host "Retrieving VPN Package and supplying to App"
    $packageUri = Get-AzureRmVpnClientPackage -ResourceGroupName $vnet.ResourceGroupName -VirtualNetworkGatewayName $gateway.Name -ProcessorArchitecture Amd64
    
    # $packageUri may contain literal double-quotes at the start and the end of the URL
    if ($packageUri.Length -gt 0 -and $packageUri.Substring(0, 1) -eq '"' -and $packageUri.Substring($packageUri.Length - 1, 1) -eq '"') {
        $packageUri = $packageUri.Substring(1, $packageUri.Length - 2)
    }

    # Put the VPN client configuration package onto the App
    $PropertiesObject = @{
        "vnetName" = $vnet.Name; "vpnPackageUri" = $packageUri
    }

    New-AzureRmResource -Location $location -Properties $PropertiesObject -ResourceName "$($webAppName)/$($vnet.Name)/primary" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections/gateways" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName -Force

    Write-Host "Finished!"
}

function RemoveVnet($subscriptionId, $resourceGroupName, $webAppName) {
    $webAppConfig = Get-AzureRmResource -ResourceName "$($webAppName)/web" -ResourceType "Microsoft.Web/sites/config" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName
    $currentVnet = $webAppConfig.Properties.VnetName
    if ($currentVnet -ne $null -and $currentVnet -ne "") {
        Write-Host "Currently connected to VNET $currentVnet"

        Remove-AzureRmResource -ResourceName "$($webAppName)/$($currentVnet)" -ResourceType "Microsoft.Web/sites/virtualNetworkConnections" -ApiVersion 2015-08-01 -ResourceGroupName $resourceGroupName
    }
    else {
        Write-Host "Not connected to a VNET."
    }
}

Write-Host "Please Login"
Login-AzureRmAccount

# Choose subscription. If there's only one we will choose automatically

$subs = Get-AzureRmSubscription
$subscriptionId = ""

if ($subs.Length -eq 0) {
    Write-Error "No subscriptions bound to this account."
    return
}

if ($subs.Length -eq 1) {
    $subscriptionId = $subs[0].SubscriptionId
}
else {
    $subscriptionChoices = @()
    $subscriptionValues = @()

    foreach ($subscription in $subs) {
        $subscriptionChoices += "$($subscription.SubscriptionName) ($($subscription.SubscriptionId))";
        $subscriptionValues += ($subscription.SubscriptionId);
    }

    $subscriptionId = PromptCustom "Choose a subscription" $subscriptionValues $subscriptionChoices
}

Select-AzureRmSubscription -SubscriptionId $subscriptionId

$resourceGroup = Read-Host "Please enter the Resource Group of your App"

$appName = Read-Host "Please enter the Name of your App"

$options = @("Add a NEW Virtual Network to an App", "Add an EXISTING Virtual Network to an App", "Remove a Virtual Network from an App");
$optionValues = @(0, 1, 2)
$option = PromptCustom "What do you want to do?" $optionValues $options

if ($option -eq 0) {
    AddNewVnet $subscriptionId $resourceGroup $appName
}
if ($option -eq 1) {
    AddExistingVnet $subscriptionId $resourceGroup $appName
}
if ($option -eq 2) {
    RemoveVnet $subscriptionId $resourceGroup $appName
}