[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$fileDirectory,

    [Parameter(Mandatory = $true)]
    [string]$TenantName,

    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [Parameter(Mandatory = $true)]
    [string]$AuthPoint,

    [Parameter(Mandatory = $true)]
    [string]$redirect
)
PROCESS {

    Get-ChildItem -path Cert:\CurrentUser\My –RECURSE | Where-Object Thumbprint -eq ("{0}" -f $Thumbprint) | Format-List -Property *



    $token = Connect-IaCADALv1Certificate -AppId $AppId -Thumbprint $Thumbprint -TenantDomain $TenantName -ResourceUri $redirect -Environment Production



    $dllpath = ".\Microsoft.Exchange.WebServices.dll"
    [void][Reflection.Assembly]::LoadFile($dllpath)
    $creds = New-Object Microsoft.Exchange.WebServices.Data.OAuthCredentials($token.AccessToken)

    ## Load EWS API
    $ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP2
    $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
    $uri = [system.URI] "https://outlook.office365.com/EWS/Exchange.asmx"
    $Service.Url = $uri
    $service.Credentials = $creds
    Clear-host
  
    $RoomMailboxName = @("room1@shawniq.onmicrosoft.com", "room2@shawniq.onmicrosoft.com")

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