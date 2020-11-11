$ClientID = 'c2d3c167-844d-40d0-9314-61aac6141ee9'
$TenantID = 'McsInternalTrials.onmicrosoft.com'
$Resource = "https://graph.microsoft.us/"
$scope = "user.read openid profile"

$DeviceCodeRequestParams = @{
    Method = 'POST'
    Uri    = "https://login.microsoftonline.us/$TenantID/oauth2/v2.0/devicecode"
    Body   = @{
        client_id = $ClientId
        scope     = $scope
    }
}

$DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow

$TokenRequestParams = @{
    Method = 'POST'
    Uri    = "https://login.microsoftonline.us/$TenantId/oauth2/v2.0/token"
    Body   = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        device_code = $DeviceCodeRequest.device_code
        client_id   = $ClientId
    }
}
$TokenRequest = Invoke-RestMethod @TokenRequestParams