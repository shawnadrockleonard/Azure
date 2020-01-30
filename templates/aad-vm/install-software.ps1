
#check for existence of the readme file to determine if this script has already run (prevents re-running on re-deployments)
$installedSoftwareTxt = "C:\installs\InstalledSoftware.txt"
if (!(Test-Path $installedSoftwareTxt)) {
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); 
  New-Item -Path "c:\installs" -ItemType Directory -Force | Out-Null
  ("{0}--Initialized" -f (get-date).ToString("o")) | Out-File -FilePath $installedSoftwareTxt;

  choco install sysinternals --params "/InstallDir:C:\installs\SysInternals" -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--sysinternals" -f (get-date).ToString("o"))
  choco install 7zip -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--7zip" -f (get-date).ToString("o"))
  choco install cmder -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--cmder" -f (get-date).ToString("o"))
  choco install googlechrome -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--googlechrome" -f (get-date).ToString("o"))
  choco install firefox -y
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--firefox" -f (get-date).ToString("o"))
  choco install git -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--git" -f (get-date).ToString("o"))
  choco install nodejs --version 10.16.2 -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--nodejs" -f (get-date).ToString("o"))
  choco install yarn -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--yarn" -f (get-date).ToString("o"))
  choco install jdk8 -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--jdk8" -f (get-date).ToString("o"))
  choco install dotnetcore-sdk --version 2.2.402 -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--dotnetcore-sdk" -f (get-date).ToString("o"))
  choco install dotnetcore-sdk --version 3.0.100 -y;  
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--dotnetcore-sdk" -f (get-date).ToString("o"))
  choco install visualstudio2019enterprise --params "--config .\vs2019.vsconfig" -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--visualstudio2019enterprise" -f (get-date).ToString("o"))
  choco install sql-server-2019 -y
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--sql-server-2019" -f (get-date).ToString("o"))
  choco install sql-server-management-studio -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--sql-server-management-studio" -f (get-date).ToString("o"))
  choco install vscode -y; 
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--vscode" -f (get-date).ToString("o"))
  choco install azure-cli -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--azure-cli" -f (get-date).ToString("o"))
  choco install microsoftazurestorageexplorer -y;
  Add-Content -Path $installedSoftwareTxt -Value ("{0}--microsoftazurestorageexplorer" -f (get-date).ToString("o"))

  #potential next steps
  #clone our solution and pull down to the server
  #test coolbridge, fbit commands, etc
  Add-Content "c:\installs\DeploymentCount.txt" "2"
}
else {
  $deploymentCount = Get-Content "c:\installs\DeploymentCount.txt"
  $deploymentCount++
  Set-Content "c:\installs\DeploymentCount.txt" $deploymentCount
}
