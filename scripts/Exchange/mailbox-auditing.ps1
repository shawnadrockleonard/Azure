
$UserCredential = Get-Credential

#$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

#Import-PSSession $Session

Get-Mailbox -ResultSize Unlimited -Filter { UserPrincipalName -like '*sleonard@.onmicrosoft.com*' } | Set-Mailbox -AuditEnabled $true