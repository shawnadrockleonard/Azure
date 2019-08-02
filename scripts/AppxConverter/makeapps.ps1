$dirpath = ("{0}\{1}\Documents" -f $env:HOMEDRIVE, $env:HOMEPATH)
$pathToApp = ("{0}\DesktopApps\RemoteMapper\setup.exe" -f $dirpath)
$destToApp = ("{0}\DesktopAppsOutput\RemoteMapper" -f $dirpath)
$appName = "MappingDrives"

Set-Location -Path $dirpath

.\DesktopAppConverter.ps1 -Installer $pathToApp -InstallerArguments "/S /v/qn" -Destination $destToApp -PackageName $appName -Publisher "CN=Shawn Leonard" -Version 0.0.0.1 -MakeAppx -Verbose


clear