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
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/reservations/readme.md", SupportsShouldProcess = $true)]
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
}
PROCESS
{

    $ordercsv = @()
    $orderusagecsv = @()
 
    $reservationFile = Join-Path -Path $logDirectory -ChildPath "Az_Reservations.json"
    if (!(Test-Path -Path $reservationFile -PathType Leaf -ErrorAction SilentlyContinue))
    {
        Write-Error "Failed to find $reservationFile on disk.  Please run get-reservations.ps1"
        exit
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

    Write-Verbose "Writing csv file to disk $rescsv"
    $ordercsv | Export-Csv -Path $rescsv -Force
    $orderusagecsv | Export-Csv -Path $resusagecsv -Force


}