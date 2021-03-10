<#
Shawn Leonard
Cloud Solution Architect - Azure PaaS & Office365 | Microsoft Federal
BLOG – https://aka.ms/shawniq/   
LinkedIn - https://aka.ms/shawn-linkedin 

.DESCRIPTION
- Will use a combo of Reservations cmdlets with REST endpoints to grab usage data

.EXAMPLE
    $orders = .\scripts\reservations\get-reservations.ps1 -Verbose
    $orders = .\scripts\reservations\get-reservations.ps1 -AzEnvironment AzureUSGovernment -Verbose
#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/reservations/readme.md", SupportsShouldProcess = $true)]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("AzureCloud", "AzureUSGovernment")]
    [string]$AzEnvironment = "AzureCloud",

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
    if ($null -eq $AzContext -or $AzEnvironment -ne $AzContext.Environment.Name)
    {
        Connect-AzAccount -Environment $AzEnvironment -UseDeviceAuthentication -ErrorAction Break
    }     

    $AzProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $AzProfile.Accounts.Count)
    {
        Write-Error "Please run Connect-AzAccount before calling this function."
        break
    }

    $reservationFile = ("{0}\Az_Reservations.json" -f $logDirectory)
}
PROCESS
{
    function Get-AzureServiceToken
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $TRUE)]
            $AzProfile
        )
        PROCESS
        {
            $currentAzureContext = Get-AzContext
            $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($AzProfile)
            Write-Verbose ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
            $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
            Write-Output $token
        }
    }

    # Reservation Date Time Query
    $queryDate = (Get-Date).AddDays(-1)
    $date = Get-Date $queryDate -Format "yyyy-MM-dd"  

    # Get Catalog of available SKUs and Number count of VMs that can fit
    # Get-AzReservationCatalog -ReservedResourceType VirtualMachines -Location usgovtexas
    # Get-AzReservationCatalog -ReservedResourceType VirtualMachines -Location usgovvirginia


    # Retreive orders
    $orderCollection = @()

    $orders = Get-AzReservationOrder | Select-Object Id, Name, Reservations, Term, RequestDateTime
    $orders | ForEach-Object { 
        $orderobj = $_
        $reservations = Get-AzReservation -ReservationOrderId $orderobj.Name 
        $reservations | ForEach-Object {
            $reservation = $_

            $reservationId = $reservation.Name.Replace(("{0}/" -f $orderobj.Name), "")

            $resobj = [PSCustomObject]@{
                OrderId        = $orderobj.Name
                Term           = $orderobj.Term
                StartDate      = $orderobj.RequestDateTime
                ReservationId  = $reservationId
                Sku            = $reservation.Sku
                SkuDescription = $reservation.SkuDescription
                Location       = $reservation.Location
                ResourceType   = $reservation.ReservedResourceType
                AppliedScope   = $reservation.AppliedScopeType
                DisplayName    = $reservation.DisplayName
                Quantity       = $reservation.Quantity
                BillingUsage   = @()
            }

            $orderCollection += $resobj
        }
    }

    $Timeout = 60
    $token = Get-AzureServiceToken -AzProfile $AzProfile
    $headers = @{
        "Authorization" = "Bearer " + $token.AccessToken 
        "user-agent"    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36"
    }

    # Retreive Management API endpoint for the authenticated account
    $resourceManagerUrl = ("{0}providers/Microsoft.Capacity/reservationorders" -f $AzContext.Environment.ResourceManagerUrl)

    
    $orderCollection | ForEach-Object {

        $orderDetails = $_
        $reservationOrder = $orderDetails.OrderId
        $reservation = $orderDetails.ReservationId

        $uri = ("$resourceManagerUrl/$reservationOrder/reservations/$reservation/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2019-10-01")
        $uri = ("$resourceManagerUrl/{0}/reservations/{1}/providers/Microsoft.Consumption/reservationDetails?`$filter=properties/usageDate+ge+{2}+AND+properties/usageDate+le+{2}&api-version=2019-10-01" -f $reservationOrder, $reservation, $date)
        Write-Verbose ("GET {0}" -f $uri)

        $attemptoken = 0
        $attemptretry = 0
        $secondsElapsed = 0
        while ($secondsElapsed -lt $Timeout)
        {
            $response = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers
            Write-Verbose ("GET {0} Status: {1}" -f $uri, $response.StatusCode)

            if ($response.StatusCode -eq 200)
            { 
                $content = $response.Content | ConvertFrom-Json
                $content.value | ForEach-Object {
                    $contentValue = $_
                    $billingObj = [PSCustomObject]@{
                        usageDate                = $contentValue.properties.usageDate
                        skuName                  = $contentValue.properties.skuName
                        instanceId               = $contentValue.properties.instanceId
                        instanceFlexibilityGroup = $contentValue.properties.instanceFlexibilityGroup
                        usedHours                = $contentValue.properties.usedHours
                    } 
                    $orderDetails.BillingUsage += $billingObj
                }
                break 
            } 
            elseif ($response.StatusCode -eq 401 -and $attemptoken -lt 2)
            {
                $attemptoken += 1
                $token = Get-AzureServiceToken -AzProfile $AzProfile
                $headers = @{"Authorization" = "Bearer " + $token.AccessToken }
                Start-Sleep -Seconds 1
                $secondsElapsed++
            }
            elseif ($response.StatusCode -eq 429 -and $attemptretry -lt 3)
            {
                $retryAfter = $response.Headers["Retry-After"]
                Write-Verbose ("API Throttled {0} waiting for {1}..." -f $uri, $retryAfter)
                Start-Sleep -Seconds $retryAfter
                $secondsElapsed++
            }
            else
            {
                Write-Verbose ("Waiting for api response {0}..." -f $uri)
                Start-Sleep -Seconds 20
                $secondsElapsed++
            }
        }

    }

    Write-Verbose "Writing $reservationFile to disk...."
    $orderCollection | ConvertTo-Json -Depth 5 | Out-File -Path $reservationFile -Force
    Write-Output $orderCollection

}
END
{
    Write-Host "Finished ..."
}
