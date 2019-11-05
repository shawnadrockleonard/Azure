
Remove-Module AzureCMCore -Force
Unblock-File -LiteralPath .\AzureCMCore.dll
tasklist.exe /m AzureCMCore.dll
