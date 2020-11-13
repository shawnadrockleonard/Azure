[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$ClientId = 'c2d3c167-844d-40d0-9314-61aac6141ee9',
 
    [Parameter(Mandatory = $true)]
    [string]$TenantId = 'McsInternalTrials.onmicrosoft.com',
 
    [Parameter(Mandatory = $false)]
    [string]$Scope = "user.read openid profile",

    [ValidateSet("AzureCloud", "AzureChinaCloud", "AzureUSGovernment", "AzureGermanCloud")]
    [ValidateNotNullOrEmpty()]
    [string]$Environment = "AzureCloud",
 
    [Parameter(Mandatory = $false)]
    [switch]$Cache
)
BEGIN {
    # Built from Get-AzEnvironment
    $envs = @(
        @{ Name        = "AzureGermanCloud"
            Management = "https://management.microsoftazure.de/" 
            Url        = "https://login.microsoftonline.de/" 
        },
        @{
            Name       = "AzureCloud"
            Management = "https://management.azure.com/"
            Url        = "https://login.microsoftonline.com/"
        },
        @{
            Name       = "AzureChinaCloud"
            Management = "https://management.chinacloudapi.cn/"
            Url        = "https://login.chinacloudapi.cn/"
        },
        @{
            Name       = "AzureUSGovernment"
            Management = "https://management.usgovcloudapi.net/"
            Url        = "https://login.microsoftonline.us/"
        }
    )
}
PROCESS {
    $TokenResponse = $null
    $SoverignCloud = $envs | Where-Object Name -eq $Environment
    $Resource = "https://graph.microsoft.us/"
    $UriDeviceCode = ("{0}{1}/oauth2/v2.0/devicecode" -f $SoverignCloud.Url, $TenantId)
    $UriToken = ("{0}{1}/oauth2/v2.0/token" -f $SoverignCloud.Url, $TenantId)


    $DeviceCodeRequestParams = @{
        Method = 'POST'
        Uri    = $UriDeviceCode
        Body   = @{
            client_id = $ClientId
            scope     = $Scope
        }
    }

    $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
    Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow

    $waitSeconds = New-TimeSpan -Seconds $DeviceCodeRequest.interval
    $expires_in = $DeviceCodeRequest.expires_in
    $span = New-TimeSpan -Seconds $expires_in

    $expiryDate = $expires_in + 100
    $expiryTime = New-TimeSpan -Seconds $expiryDate

    while ($span.TotalSeconds -gt 0) {
        Start-Sleep -Seconds $waitSeconds.TotalSeconds

        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = $UriToken
            Body   = @{
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                device_code = $DeviceCodeRequest.device_code
                client_id   = $ClientId
            }
        }
        $TokenResponse = Invoke-RestMethod -StatusCodeVariable statusCode -SkipHttpErrorCheck @TokenRequestParams
        if ($statusCode -eq 200) {
            $span = $span.Subtract($expiryTime)
            $Global:accessTokenResult = $TokenResponse
        }

        if (($TokenResponse.error | Measure-Object).Count -gt 0) {
            if ($TokenResponse.error -ne "authorization_pending") {
                throw ("Failed /{0}/ and needs to terminate." -f $TokenResponse.error)
            }
        }

        $span = $span.Subtract($waitSeconds)
    }

    Write-Output $TokenResponse
}