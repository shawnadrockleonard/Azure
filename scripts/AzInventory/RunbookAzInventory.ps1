<#
    .DESCRIPTION
        A runbook to retreive all resources in the subscription
#>

$connectionName = "AzureRunAsConnection"
try
{
    Import-Module Az.Accounts -MinimumVersion 2.2.6
    Import-module Az.Resources -MinimumVersion 3.3.0
    Import-module Az.Compute -MinimumVersion 4.10.0
    Import-module Az.Network -MinimumVersion 4.6.0
    Import-module Az.Storage -MinimumVersion 3.5.0
    Import-module Az.Automation -MinimumVersion 1.5.2


    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
    $getStorage = Get-AutomationPSCredential -Name "AzStorage"

    "Logging in to Azure..."
    Connect-AzAccount -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -Environment AzureUSGovernment
}
catch
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
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
        # Write file to disk        
        $collection | Export-Csv -Path $localFile -Force -NoTypeInformation

        # Create Storage Container if it doesn't exist already
        Write-Output "Check if Container exists:"
        $exists = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue -Debug:$DebugPreference
        If (!$exists)
        {
            Write-Output "Container $ContainerName Not Found, Creating Container $ContainerName" 
            New-AzStorageContainer -Name $ContainerName -Context $ctx -Permission Off
        } 

        Write-Output "File exists and size is sufficient for uploading" 
        $file = Get-Item -Path $localFile
        $sourceFileMD5hash = Get-FileHash -Algorithm MD5 $localFile

        #Set MetaData
        $Metadata = @{
            "CurrentStamp" = $CurrentStamp.trim();  
            "MD5Hash"      = $sourceFileMD5hash.Hash.trim() 
        }
        Write-Output $Metadata
        #upload blob to Azure
        $blob = Set-AzStorageBlobContent -File $localFile -Container $ContainerName -Blob $file.Name -Context $ctx -Metadata $Metadata -Force
        if ($null -ne $blob)
        {
            $uploaded = $true
            Write-Output "$localfile uploaded to Storage Account:$($ctx.StorageAccountName), Container:$ContainerName" 
            Write-Output "Successfully uploaded $($blob.Name) at $($blob.LastModified) in the Tier:$($blob.AccessTier)"
        }
        else
        {
            Write-Output "Failed to upload $localfile, Consult the logs."
            Write-Error "Failed to upload $localfile, Consult the logs."
        }
    }
} 

$todaydate = Get-Date -Format "yyyy-MM-dd"
$LogFull = "AzureScan-$todaydate.log" 
$LogItem = New-Item -ItemType File -Name $LogFull

"  Text to write" | Out-File -FilePath $LogFull -Append
$temp = Get-ChildItem -Path $LogItem
$logDirectory = $temp.Directory.FullName
Write-Output ("Directory {0} with Log {1}" -f $logDirectory, $temp.FullName)


$ctx = New-AzStorageContext -StorageAccountName $getStorage.UserName -StorageAccountKey $getStorage.GetNetworkCredential().Password  -Environment AzureUSGovernment 
Write-Output $ctx.BlobEndPoint


$sizesVA = Get-AzVMSize -Location usgovvirginia
$sizesTX = Get-AzVMSize -Location usgovtexas



#Get all ARM resources from all resource groups
$ResourceGroups = Get-AzResourceGroup | select-object ResourceGroupName, Location

foreach ($ResourceGroup in $ResourceGroups)
{    
    Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
    $Resources = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName | Select-Object ResourceName, ResourceType
    ForEach ($Resource in $Resources)
    {
        Write-Output ($Resource.ResourceName + " of type " + $Resource.ResourceType)
    }
    Write-Output ("")
} 


$storagecollection = @()
$vmcollection = @()
$vmdisks = @()
$vmnics = @()

$vnetcollection = @()
$vnetsubnets = @()
$vnetpeerings = @()

$diskcollection = @()


$vnetfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VNets.csv"
$vnetsubnetfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VNet_Subnets.csv"
$vnetpeeringfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VNet_Peerings.csv"
$vmfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VMs.csv"
$vmnicfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VM_Nics.csv"
$vmdiskfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_VM_Disks.csv"
$storagefile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_Storage.csv"
$sizevafile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_Sizes_VA.csv"
$sizetxfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_Sizes_TX.csv"
$storagediskfile = Join-Path -Path $logDirectory -ChildPath "Az_Inventory_Storage_Disks.csv"


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

# Virtual Network Details
Write-Output ("Writing VNET details Found ##{0}" -f (($vnetcollection | Measure-Object).Count))
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetfile -currentStamp $todaydate -collection $vnetcollection
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetsubnetfile -currentStamp $todaydate -collection $vnetsubnets
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vnetpeeringfile -currentStamp $todaydate -collection $vnetpeerings
      
# Virtual Machine Details
Write-Verbose ("Writing VM details")
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmfile -currentStamp $todaydate -collection $vmcollection
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmnicfile -currentStamp $todaydate -collection $vmnics
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $vmdiskfile -currentStamp $todaydate -collection $vmdisks
          
# Storage Details
Write-Output ("Writing Storage details")
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $storagefile -currentStamp $todaydate -collection $storagecollection

# Virtual Machine sizing
Write-Output ("Writing VM Sizes")
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $sizevafile -currentStamp $todaydate -collection $sizesVA
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $sizetxfile -currentStamp $todaydate -collection $sizesTX

# Unattached disks
Write-Verbose ("Writing Storage disk details")
Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $storagediskfile -currentStamp $todaydate -collection $diskcollection

Write-Output "Finished ..."