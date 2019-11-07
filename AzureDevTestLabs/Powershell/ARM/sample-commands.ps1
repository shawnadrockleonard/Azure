#  Connection
Connect-AzAccount -Environment AzureCloud | Out-Null
# Get Environments
Get-AzEnvironment
# Get Regions
Get-AzLocation | sort Location | ft Location, DisplayName
# Timezones for AutoShutdown
Get-TimeZone -ListAvailable | Format-Table Id, BaseUtcOffset




