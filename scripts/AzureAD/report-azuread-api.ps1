<# 
    This script will require the Web Application and permissions setup in Azure Active Directory
#>
[cmdletbinding()]
param(
    [ValidateScript( { Test-Path $_ -PathType 'Container' })] 
    [string]$DestPath = $(Read-Host -prompt "destination path"),
    [Parameter(HelpMessage = "Should be a ~35 character string insert your info here")]
    [string]$ClientID = $(Read-Host -prompt "Client ID: Should be a ~35 character string insert your info here"),
    [Parameter(HelpMessage = "Should be a ~44 character string insert your info here")]
    [string]$ClientSecret = $(Read-Host -prompt "Client Secret: Should be a ~44 character string insert your info here"), 
    [string]$loginURL = "https://login.windows.net",
    [Parameter(HelpMessage = "For example, contoso.onmicrosoft.com")]
    [string]$tenantdomain = $(Read-Host -prompt "tenant domain"),
    [string]$tenantId = $(Read-Host -prompt "tenant ID")
)
PROCESS {
    # Get an Oauth 2 access token based on client id, secret and tenant domain
    $body = @{grant_type = "client_credentials"; resource = $resource; client_id = $ClientID; client_secret = $ClientSecret }
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body

    $7daysago = "{0:s}" -f (get-date).AddDays(-7) + "Z"
    # or, AddMinutes(-5)

    Write-Output $7daysago

    if ($oauth.access_token -ne $null) {
        $headerParams = @{'Authorization' = "$($oauth.token_type) $($oauth.access_token)" }

        $url = "https://graph.windows.net/$tenantdomain/reports/auditEvents?api-version=beta&\`$filter=eventTime gt $7daysago"

        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url)
        foreach ($event in ($myReport.Content | ConvertFrom-Json).value) {
            Write-Output ($event | ConvertTo-Json)
        }
        $myReport.Content | Out-File -FilePath C:\vData\auditEvents.json -Force
    }
    else {
        Write-Host "ERROR: No Access Token"
    }
}