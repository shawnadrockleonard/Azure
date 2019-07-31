Import-Module ADFS
Get-ADFSClaimsProviderTrust | Out-File “.\cptrusts.txt”
Get-ADFSRelyingPartyTrust | Out-File “.\rptrusts.txt”


Get-Command * -module ADFS