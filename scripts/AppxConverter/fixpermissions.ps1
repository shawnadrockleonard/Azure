cd C:\DesktopAppConverter\
.\DesktopAppConverter.ps1 -Setup -BaseImage .\BaseImage-14342.wim -Verbose


Get-ChildItem -Path . -Recurse | ForEach-Object {
    Write-Host ("Unblocking {0}" -f $_.FullName)
    Unblock-File -Path $_.FullName
}