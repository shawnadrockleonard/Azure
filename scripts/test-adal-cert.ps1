<#

    .\test-adal-cert.ps1 -AppId "c2995170-cd3f-4ea4-9a26-71a6e09ad596" -Thumbprint "81A0D703312B286DF3DB8A57D6B24E44D116018D"

    .\test-adal-cert.ps1 -AppId "790558b8-68d9-4e9b-b58b-7d5a0eec02f5" -Thumbprint "d61977118a763f4bb30e5919929f727fa9336c06"
#>
Param
(
    [Parameter(Mandatory = $true, HelpMessage = "Enter Azure AD Tenant Name")]
    [string] $TenantName,

    [Parameter(Mandatory = $true, HelpMessage = "Enter Azure AD App Id")]
    [string] $AppId,

    [Parameter(Mandatory = $true, HelpMessage = "Enter Certificate Thumbprint")]
    [string] $Thumbprint,

    [Parameter(Mandatory = $false, HelpMessage = "Enter Azure AD Common EndPoint")]
    [string] $AuthPoint = "https://login.microsoftonline.com",

    [Parameter(Mandatory = $false, HelpMessage = "Enter Azure AD ReplyURI")]
    [string] $redirect = "https://outlook.office365.com"

)
PROCESS {

    Get-ChildItem -path Cert:\CurrentUser\My –RECURSE | Where-Object Thumbprint -eq ("{0}" -f $Thumbprint) | Format-List -Property *



    Connect-IaCADALv1Certificate -AppId $AppId -Thumbprint $Thumbprint -TenantDomain $TenantName -ResourceUri $redirect -Environment Production



    $token = Connect-IaCADALv1Certificate -AppId $AppId -Thumbprint $Thumbprint -TenantDomain $TenantName -ResourceUri $redirect -Environment Production



    $dllpath = "C:\source\shawniq-github\ewssync\src\ews-managed-api-master\bin\Debug\Microsoft.Exchange.WebServices.dll"
    [void][Reflection.Assembly]::LoadFile($dllpath)
    $creds = New-Object Microsoft.Exchange.WebServices.Data.OAuthCredentials($token.AccessToken)

    ## Load EWS API
    $ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP2
    $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
    $uri = [system.URI] "https://outlook.office365.com/EWS/Exchange.asmx"
    $Service.Url = $uri
    $service.Credentials = $creds
    Clear-host
  
    $RoomMailboxName = @(("room1@{0}" -f $TenantName), ("room2@{0}" -f $TenantName))

    Foreach ($Rmbx in $RoomMailboxName) {
        Write-Output ("Now impersonating {0}" -f $Rmbx)
        $service.ImpersonatedUserId = New-Object Microsoft.exchange.webservices.data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $Rmbx)

        $StartDate = new-object System.DateTime(2018, 01, 01)
        $EndDate = new-object System.DateTime(2019, 01, 31)

        $folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar, $Rmbx)
        $CalFolder = [Microsoft.Exchange.WebServices.Data.CalendarFolder]::Bind($service, $folderid)

        $cvCalview = new-object Microsoft.Exchange.WebServices.Data.CalendarView($StartDate, $EndDate, 2000)
        $cvCalview.PropertySet = new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
        $CalResult = $CalFolder.FindAppointments($cvCalview)
        $CalResult | Select-Object DisplayTo, DateTimeSent, Start, End, Duration, TimeZone, Organizer
    }
}