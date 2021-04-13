<#
Shawn Leonard
Cloud Solution Architect - Azure PaaS & Office365 | Microsoft Federal
BLOG – https://aka.ms/shawniq/   
LinkedIn - https://aka.ms/shawn-linkedin 

.DESCRIPTION
- Will take an inventory of Reservations and parse data into specific locations

.EXAMPLE
    .\scripts\reservations\parse-reservations.ps1 -Verbose

#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/azreservations/readme.md", SupportsShouldProcess = $true)]
[CmdletBinding()]
param (
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
        Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication -ErrorAction Suspend
    }   
    
    function Get-AzConfigJson
    {
        [cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/azreservations/readme.md")]
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
        [cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/azreservations/readme.md")]
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
            else {
                Write-Error "Failed to upload $localfile, Consult the logs."
            }
        }
        END
        {
            Write-Output $uploaded
        }
    }      
}
PROCESS
{

    $ordercsv = @()
    $orderusagecsv = @()
 
    $reservationFile = Join-Path -Path $logDirectory -ChildPath "Az_Reservations.json"
    if (!(Test-Path -Path $reservationFile))
    {
        throw "Could not find $reservationFile Run get-reservations.ps1"
    }
    
    $rescsv = ("{0}\Az_Reservations.csv" -f $logDirectory)
    $resusagecsv = ("{0}\Az_ReservationUsage.csv" -f $logDirectory)

    Write-Verbose "Reading reservation file $reservationFile"
    $orders = get-content $reservationFile -raw | ConvertFrom-Json

    foreach ($orderobj in $orders)
    {
        $orderbilling = $orderobj.BillingUsage
        $orderdet = [PSCustomObject]@{
            OrderId        = $orderobj.OrderId
            Term           = $orderobj.Term
            StartDate      = $orderobj.StartDate
            ReservationId  = $orderobj.ReservationId
            Sku            = $orderobj.Sku
            SkuDescription = $orderobj.SkuDescription
            Location       = $orderobj.Location
            ResourceType   = $orderobj.ResourceType
            AppliedScope   = $orderobj.AppliedScope
            DisplayName    = $orderobj.DisplayName
            Quantity       = $orderobj.Quantity
        }
        $ordercsv += $orderdet

        foreach ($orderbillingobj in $orderbilling)
        {
            $resourceId = $orderbillingobj.instanceId
            Write-Verbose "Querying Az for resource $resourceId"
            $vmresource = Get-AzResource -ResourceId $resourceId

            $orderbillingdet = [PSCustomObject]@{
                OrderId       = $orderobj.OrderId
                Sku           = $orderobj.Sku
                Quantity      = $orderobj.Quantity
                DisplayName   = $orderobj.DisplayName
                UsageDate     = $orderbillingobj.usageDate
                UsedHours     = $orderbillingobj.usedHours
                Name          = $vmresource.Name
                ResourceGroup = $vmresource.ResourceGroupName
                Location      = $vmresource.Location
            }
            $orderusagecsv += $orderbillingdet
        }
    }

    $date = Get-Date -Format "yyyy-MM-dd"
    $jsonFile = Join-Path -Path $RunningDirectory -ChildPath "config.json"
    $config = Get-AzConfigJson $jsonFile
    $ctx = New-AzStorageContext -StorageAccountName $config.storageAccountName -StorageAccountKey $config.storageKey


    # Virtual Machine sizing
    Write-Verbose "Writing reservation csvs"
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $rescsv -currentStamp $date -collection $ordercsv
    Update-AzInventory -ctx $ctx -ContainerName "azinventory" -localFile $resusagecsv -currentStamp $date -collection $orderusagecsv
}