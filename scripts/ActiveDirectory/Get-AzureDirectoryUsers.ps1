
[CmdletBinding(HelpURI='http://portal.azure.com')]
    param(
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$tenantDirectory,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantFile,
    
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$upn
)

$outputhash = @()

Function GetFirstString([System.Collections.Generic.List[String]]$list) {
    $altvar = $null
    if($list.length -gt 0) {
        $altvar = $list[0]
    }
    return $altvar
}

Function GetFirstSecurityId([System.Collections.Generic.List[Microsoft.Online.Administration.AlternativeSecurityId]]$list) {
    $altvar = $null
    if($list.length -gt 0) {
        $altvar = $list[0].Type
    }
    return $altvar
}

# connect with a user who has access to the Tenant
Connect-MsolService -Credential (Get-Credential)

Get-MsolUser | 
    Where { $_.UserPrincipalName -like "*$($upn)*" } | 
        ForEach-Object {

    $usrObj = $_
    $altemailvar = GetFirstString $usrObj.AlternateEmailAddresses
    $altmobilevar = GetFirstString $usrObj.AlternateMobilePhones
    $altsecurityid = GetFirstSecurityId $usrObj.AlternativeSecurityIds
    $proxyaddress = GetFirstString $usrObj.ProxyAddresses

    Write-Verbose "Now writing object principal $($usrObj.DisplayName) to CSV collection."

    $hash = New-Object psobject -Property @{
        ObjectId = $usrObj.ObjectId
        AlternateEmailAddresses = $altemailvar
        AlternateMobilePhones = $altmobilevar
        ProxyAddresses = $proxyaddress
        AlternativeSecurityIds = $altsecurityid
        DisplayName = $usrObj.DisplayName
        FirstName = $usrObj.FirstName
        LastName = $usrObj.LastName
        LastPasswordChangeTimestamp = $usrObj.LastPasswordChangeTimestamp
        MobilePhone = $usrObj.MobilePhone
        Office = $usrObj.Office
        SignInName = $usrObj.SignInName
        StrongPasswordRequired = $usrObj.StrongPasswordRequired
        StsRefreshTokensValidFrom = $usrObj.StsRefreshTokensValidFrom
        Title = $usrObj.Title
        UsageLocation = $usrObj.UsageLocation
        UserPrincipalName = $usrObj.UserPrincipalName
        UserType = $usrObj.UserType
        ValidationStatus = $usrObj.ValidationStatus
        WhenCreated = $usrObj.WhenCreated
    }

    $outputhash += $hash
}

$items = @($outputhash)

if($items.Count -gt 0) {

    $tenantFileWithDirectory = ("{0}\{1}" -f $tenantDirectory,$tenantFile)

    Write-Verbose "Now writing CSV to file $($tenantFileWithDirectory)"
    $items | Export-Csv -LiteralPath $tenantFileWithDirectory
}