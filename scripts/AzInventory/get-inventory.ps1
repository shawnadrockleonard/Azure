<#
Shawn Leonard
Cloud Solution Architect - Azure PaaS & Office365 | Microsoft Federal
BLOG – https://aka.ms/shawniq/   
LinkedIn - https://aka.ms/shawn-linkedin 

.DESCRIPTION
- Will query Azure parsing the subscriptions for resources

.EXAMPLE
    .\scripts\AzInventory\get-inventory.ps1 -Verbose 
    
#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzInventory/readme.md", SupportsShouldProcess = $true)]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType Container })]
    [string]$RunningDirectory
)
BEGIN
{
    # Specifies the directory in which this should run
    $runningscriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if ($RunningDirectory -eq "")
    {
        $RunningDirectory = $runningscriptDirectory
    }
        
    $logDirectory = Join-Path -Path $RunningDirectory -ChildPath "_logs"
    if (!(Test-Path -Path $logDirectory -PathType Container))
    {
        New-Item -Path $logDirectory -Force -ItemType Directory -WhatIf:$false | Out-Null
        $logDirectory = Join-Path -Path $RunningDirectory -ChildPath '_logs' -Resolve
    }     

    $AzContext = Get-AzContext
    if ($null -eq $AzContext)
    {
        Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication -ErrorAction Stop
    }   
    else
    {
        try
        {
            $error.Clear()
            Select-AzSubscription -SubscriptionId $AzContext.Subscription.Id -ErrorAction Stop
        }
        catch
        {
            Write-Host "An error occurred, Please re-authenticate."
            Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication -ErrorAction Stop
        }
    }  

    $AzProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $AzProfile.Accounts.Count)
    {
        Write-Error "Please run Connect-AzAccount before calling this function."
        break
    }    

    function Get-AzConfigJson
    {
        [cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzInventory/readme.md")]
        param(
            [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
            [Parameter(Mandatory = $True, Position = 0, ParameterSetName = '')][string]$jsonFile
        )
        PROCESS
        {
            $json = Get-Content -Raw -Path $jsonFile
            $configKeys = ConvertFrom-Json -InputObject $json
            Write-Output $configKeys
        }
    }     

    function Update-AzInventory
    {
        [cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzInventory/readme.md")]
        param(
            [Parameter(Mandatory = $True)]$ctx,
            [Parameter(Mandatory = $False)][string]$ContainerName = "azinventory",
            [Parameter(Mandatory = $True)][string]$localFile,
            [Parameter(Mandatory = $True)][string]$CurrentStamp,
            [Parameter(Mandatory = $True)]$collection
        )
        PROCESS
        {
            $uploaded = $false
            # Write file to disk        
            $collection | Export-Csv -Path $localFile -Force -NoTypeInformation

            # Create Storage Container if it doesn't exist already
            Write-Debug "Check if Container exists:"
            $exists = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue -Debug:$DebugPreference
            If (!$exists)
            {
                Write-Debug "Container $ContainerName Not Found, Creating Container $ContainerName" 
                New-AzStorageContainer -Name $ContainerName -Context $ctx -Permission Off
            } 

            Write-Debug "File exists and size is sufficient for uploading" 
            $file = Get-Item -Path $localFile
            $sourceFileMD5hash = Get-FileHash -Algorithm MD5 $localFile

            #Set MetaData
            $Metadata = @{
                "CurrentStamp" = $CurrentStamp.trim();  
                "MD5Hash"      = $sourceFileMD5hash.Hash.trim() 
            }
            #upload blob to Azure
            $blob = Set-AzStorageBlobContent -File $localFile -Container $ContainerName -Blob $file.Name -Context $ctx -Metadata $Metadata -Force -ErrorAction Stop
            if ($null -ne $blob)
            {
                $uploaded = $true
                Write-Host "$localfile uploaded to Storage Account:$($ctx.StorageAccountName), Container:$ContainerName" 
                Write-Host "Successfully uploaded $($blob.Name) at $($blob.LastModified) in the Tier:$($blob.AccessTier)"
            }
            else
            {
                Write-Error "Failed to upload $localfile, Consult the logs."
            }
        }
        END
        {
            Write-Output $uploaded
        }
    } 

    $storagecollection = @()
    $vmcollection = @()
    $vmdisks = @()
    $vmnics = @()

    $vnetcollection = @()
    $vnetsubnets = @()
    $vnetpeerings = @()

    $diskcollection = @()

    $todaydate = Get-Date -Format "yyyy-MM-dd"
    $jsonFile = Join-Path -Path $RunningDirectory -ChildPath "config.json"
    $vnetfile = ("{0}\Az_Inventory_VNets.csv" -f $logDirectory)
    $vnetsubnetfile = ("{0}\Az_Inventory_VNet_Subnets.csv" -f $logDirectory)
    $vnetpeeringfile = ("{0}\Az_Inventory_VNet_Peerings.csv" -f $logDirectory)
    $vmfile = ("{0}\Az_Inventory_VMs.csv" -f $logDirectory)
    $vmnicfile = ("{0}\Az_Inventory_VM_Nics.csv" -f $logDirectory)
    $vmdiskfile = ("{0}\Az_Inventory_VM_Disks.csv" -f $logDirectory)
    $storagefile = ("{0}\Az_Inventory_Storage.csv" -f $logDirectory)
    $sizevafile = ("{0}\Az_Inventory_Sizes_VA.csv" -f $logDirectory)
    $sizetxfile = ("{0}\Az_Inventory_Sizes_TX.csv" -f $logDirectory)
    $storagediskfile = ("{0}\Az_Inventory_Storage_Disks.csv" -f $logDirectory)

}
PROCESS
{
    $sizesVA = Get-AzVMSize -Location usgovvirginia
    $sizesTX = Get-AzVMSize -Location usgovtexas

    $subscriptions = Get-AzSubscription
    $subscriptions | ForEach-Object {
        $subName = $_.Name
        $subId = $_.Id
        Select-AzSubscription -SubscriptionObject $_

        Write-verbose ("Pulling VNETs from subscription {0}" -f $subName)
        $networks = Get-AzVirtualNetwork
        $networks | ForEach-Object {
            $network = $_

            $vnetprefixes = @()
            $network.AddressSpace.AddressPrefixes | ForEach-Object {
                $vnetprefixes += $_
            }

            $networkObj = [PSCustomObject]@{
                name           = $network.Name
                resourcegroup  = $network.ResourceGroupName
                subscription   = $subName
                subscriptionId = $subId
                addressSpace   = ($vnetprefixes -join ";")
            }
            $vnetcollection += $networkObj

        
            Write-verbose ("Retreiving VNET data for {0}" -f $network.Name)

            $network.Subnets | ForEach-Object {
                $subnet = $_
                $nsgName = ""
                Write-verbose ("Retreiving Subnet Details {0}" -f $subnet.Name)
                if (($subnet.NetworkSecurityGroup | Measure-Object).Count -gt 0)
                {
                    $nsgResource = Get-AzResource -resourceid $subnet.NetworkSecurityGroup.Id
                    $nsgName = $nsgResource.Name
                }

                $subnetAddresses = @()
                $subnet.AddressPrefix | ForEach-Object {
                    $subnetAddresses += $_
                }

                $subnetObj = [PSCustomObject]@{
                    vnetname     = $network.Name
                    name         = $subnet.Name
                    addressSpace = ($subnetAddresses -join ";")
                    subnetId     = $subnet.Id
                    nsg          = $nsgName
                }
                $vnetsubnets += $subnetObj
            }

            $network.VirtualNetworkPeerings | ForEach-Object {
                $peering = $_
                $remoteVnetName = 'unknown'
                Write-verbose ("Retreiving Peering Details {0}" -f $peering.Name)
                try
                {
                    $remotePeerVnet = Get-AzResource -resourceId $peering.RemoteVirtualNetwork.Id -ErrorAction:SilentlyContinue
                    if ($null -ne $remotePeerVnet)
                    {
                        $remoteVnetName = $remotePeerVnet.Name
                    }
                }
                catch
                {
                }
                
                $peeringAddresses = @()
                $peering.RemoteVirtualNetworkAddressSpace.AddressPrefixes | ForEach-Object {
                    $peeringAddresses += $_
                }

                $peeringObj = [PSCustomObject]@{
                    vnetname          = $network.Name
                    name              = $peering.Name
                    state             = $peering.PeeringState
                    remoteVNet        = $remoteVnetName
                    remoteVNetAddress = ($peeringAddresses -join ";")
                }
                $vnetpeerings += $peeringObj
            }

        }

        Write-verbose ("Pulling VMs from subscription {0}" -f $subName)
        $vms = Get-AzVM
        $vms | ForEach-Object {
            $vm = $_
            $vmsize = $vm.HardwareProfile.VmSize
            $vmlocation = $vm.Location
            $computername = $_.name
            $vmtags = $vm.Tags
            $vmsizecpu = 0
            $vmsizeram = 0
            $imagePublisher = ""
            $imageSku = ""
            Write-verbose ("Retreiving VM Details {0}" -f $vm.Name)

            if ($vmlocation -eq 'usgovvirginia')
            {
                $size = $sizesVA | Where-Object name -eq $vmsize
                $vmsizecpu = $size.NumberOfCores
                $vmsizeram = $size.MemoryInMB
            }
            elseif ($vmlocation -eq 'usgovtexas')
            {
                $size = $sizesTX | Where-Object name -eq $vmsize
                $vmsizecpu = $size.NumberOfCores
                $vmsizeram = $size.MemoryInMB
            }

            Write-verbose ("Retreiving VM data for {0}" -f $computername)

            $vmstate = $vm | Get-AzVM -Status
            $status = $vmstate.Statuses | Where-Object Code -like 'powerstate/*'

            $vmsource = "ASR"
            $timezone = "unknown"
            if (($vm.OSProfile.WindowsConfiguration | Measure-Object).Count -gt 0)
            {
                $vmsource = "Windows"
                $timezone = $vm.OSProfile.WindowsConfiguration.TimeZone
            }
            if (($vm.OSProfile.LinuxConfiguration | Measure-Object).Count -gt 0)
            {
                $vmsource = "Linux"
            }
            if (($vm.StorageProfile.ImageReference | Measure-Object).Count -gt 0)
            {
                $imagePublisher = $vm.StorageProfile.ImageReference.Publisher
                $imageSku = $vm.StorageProfile.ImageReference.Sku
            }
        
            $vmdetails = [PSCustomObject]@{
                name             = $computername
                resourcegroup    = $vm.ResourceGroupName
                location         = $vmlocation
                computername     = $vm.OSProfile.ComputerName
                vmtype           = $vmsize
                vmvcpu           = $vmsizecpu
                vmvram           = $vmsizeram
                subscription     = $subName
                subscriptionId   = $subId
                resourcetype     = 'Virtual Machine'
                state            = $status.DisplayStatus
                tag_environment  = $vmtags.Environment
                tag_service      = $vmtags.Service
                tag_serviceOwner = $vmtags.'Service Owner'
                tag_createdBy    = $vmtags.CreatedBy
                tag_backupPolicy = $vmtags.BackupPolicy
                tag_purpose      = $vmtags.Purpose
                tag_sla          = $vmtags.SLA
                vm_publisher     = $imagePublisher
                vm_sku           = $imageSku
                vm_source        = $vmsource 
                vm_timezone      = $timezone
            }
            $vmcollection += $vmdetails

            $storageOS = $vm.StorageProfile.OsDisk
            if (($storageOS.ManagedDisk | Measure-Object).Count -gt 0)
            {
                Write-verbose ("Retreiving VM Disk OS {0}" -f $vm.Name)
                $osResourceId = Get-AzResource -ResourceId $storageOS.ManagedDisk.Id
                $storageOSDisk = get-azdisk -ResourceGroupName $osResourceId.ResourceGroupName -DiskName $osResourceId.Name
                $storageObj = [PSCustomObject]@{
                    storageProfile = 'os'
                    storageType    = $storageOSDisk.Sku.Name
                    storageName    = $storageOSDisk.Sku.Name
                    storageSize    = $storageOSDisk.DiskSizeGB
                    computername   = $computername
                }
                $vmdisks += $storageObj
            }

            if (($vm.StorageProfile.DataDisks | Measure-Object).Count -gt 0)
            {
                $vm.StorageProfile.DataDisks | ForEach-Object {
                    $storageData = $_
                    Write-verbose ("Retreiving VM Disk Data {0}" -f $vm.Name)
                    $storageDataDisk = Get-azdisk -ResourceGroupName $vm.ResourceGroupName -Name $storageData.Name
                    $storageObj = [PSCustomObject]@{
                        storageProfile = 'data'
                        storageType    = $storageDataDisk.Sku.Tier
                        storageName    = $storageDataDisk.Sku.Name
                        storageSize    = $storageDataDisk.DiskSizeGB
                        computername   = $computername
                    }
                    $vmdisks += $storageObj
                }
            }

            if (($vm.NetworkProfile.NetworkInterfaces | Measure-Object).Count -gt 0)
            {
                $vm.NetworkProfile.NetworkInterfaces | ForEach-Object {
                    $nic = $_
                    Write-verbose ("Retreiving VM NIC {0}" -f $nic.Id)
                    $nicResourceId = Get-AzResource -ResourceId $nic.Id
                    $nicProfile = Get-AzNetworkInterface -Name $nicResourceId.Name -ResourceGroupName $nicResourceId.ResourceGroupName
                    $nicProfile.IpConfigurations | ForEach-Object {
                        $ipconfig = $_
                        $nicObj = [PSCustomObject]@{
                            ip           = $ipconfig.PrivateIpAddress
                            method       = $ipconfig.PrivateIpAllocationMethod
                            haspip       = (($ipconfig.PublicIpAddress | Measure-Object).Count -gt 0)
                            subnetId     = $ipconfig.Subnet.Id
                            nicName      = $nicResourceId.Name
                            computername = $computername
                        }

                        $vmnics += $nicObj
                    }
                }
            }

        }

        Write-verbose ("Pulling Storage Accounts from subscription {0}" -f $subName)
        $storages = Get-AzStorageAccount
        $storages | foreach-object {
            $storage = $_

            Write-verbose ("Retreiving Storage Account data for {0}" -f $storage.Name)
            $storageObj = [PSCustomObject]@{
                name           = $storage.StorageAccountName
                resourcegroup  = $storage.ResourceGroupName
                location       = $storage.Location
                address        = $storage.PrimaryEndpoints.Blob
                storagesku     = $storage.Sku.Name
                storagetype    = $storage.Kind
                storagetier    = $storage.AccessTier
                secondary      = $storage.SecondaryLocation
                subscription   = $subName
                subscriptionId = $subId
                resourcetype   = 'Storage Account'
            }

            $storagecollection += $storageObj
        }

        Write-verbose ("Pulling disk status {0}" -f $subName)
        $disks = Get-AzDisk
        $disks | ForEach-Object {
            $disk = $_
            $diskObj = [PSCustomObject]@{
                resourcegroup  = $disk.ResourceGroupName
                vmId           = $disk.ManagedBy
                name           = $disk.Name
                ostype         = $disk.OsType
                osSkuName      = $disk.Sku.Name
                osSkuTier      = $disk.Sku.Tier
                diskSizeGb     = $disk.DiskSizeGB
                diskState      = $disk.DiskState
                diskType       = $disk.Type
                subscription   = $subName
                subscriptionId = $subId
                resourcetype   = 'Storage Disk'
            }
            $diskcollection += $diskObj
        }
    }

    $config = Get-AzConfigJson $jsonFile
    $ctx = New-AzStorageContext -StorageAccountName $config.storageAccountName -StorageAccountKey $config.storageKey

    # Virtual Network Details
    Write-Verbose ("Writing VNET details")
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetfile -currentStamp $todaydate -collection $vnetcollection
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetsubnetfile -currentStamp $todaydate -collection $vnetsubnets
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetpeeringfile -currentStamp $todaydate -collection $vnetpeerings
    
    # Virtual Machine Details
    Write-Verbose ("Writing VM details")
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmfile -currentStamp $todaydate -collection $vmcollection
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmnicfile -currentStamp $todaydate -collection $vmnics
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmdiskfile -currentStamp $todaydate -collection $vmdisks
    
    # Storage Details
    Write-Verbose ("Writing Storage details")
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $storagefile -currentStamp $todaydate -collection $storagecollection

    # Virtual Machine sizing
    Write-Verbose ("Writing VM Sizes")
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $sizevafile -currentStamp $todaydate -collection $sizesVA
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $sizetxfile -currentStamp $todaydate -collection $sizesTX

    # Unattached disks
    Write-Verbose ("Writing Storage disk details")
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $storagediskfile -currentStamp $todaydate -collection $diskcollection
}
END
{
    Write-Host "Finished ..."
}
